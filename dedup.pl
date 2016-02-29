#!/usr/bin/perl
chdir '/usr/share/ruby/snmp';
opendir (M1, 'mibs.1');
@files = grep(/yaml$/, readdir(M1));
closedir M1;
$astat = (stat("mibs.1/$files[0]"))[9];
$bstat = (stat("mibs.2/$files[0]"))[9];
if ($astat > $bstat) {
  $src = 'mibs.1';
  $dst = 'mibs.2';
  print "Source is mibs.1\n";
}
else {
  $src = 'mibs.2';
  $dst = 'mibs.1';
  print "Source is mibs.2\n";
}
opendir (M1, $src);
@files = grep(/yaml$/, readdir(M1));
closedir M1;
foreach $f (@files) {
  die "Can't open $src/$f" unless open (SRC, "$src/$f");
  die "Can't open $dst/$f for writing" unless open (DST, ">$dst/$f");
  while (<SRC>) {
    $print_ok = 1;
    foreach $oid (@ARGV) {
      if (/^$oid:/) {
        $first{$oid} += 1;
        if ($first{$oid} > 1) {
          $print_ok = 0;
        }
      }
    }
    if ($print_ok) {
      print (DST $_);
    }
  }
  close SRC;
  close DST;
}