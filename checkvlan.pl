#!/usr/bin/perl
# Verify vlan membership of listed ports.

require "netmap.ph";
use Mysql;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
GetOptions('test' => \$test, 'd' => \$debug, 'i' => \$interact, 'quiet' => \$quiet, 'man', 'help')
  or pod2usage({-msg => 'Unknown parameter supplied.', -verbose => 0});

pod2usage(-verbose => 1) if $opt_help;
pod2usage(-verbose => 2) if $opt_man;

$update = $interact ? 0 : 1;
if ($test) {
  $db = 'netmap_development';
  $dbhost = 'localhost';
  $dbuser = 'root';
  $dbpw = 'nutbar';
  use Data::Dumper;
}
else {
  $db = 'netmap_production';
  $dbhost = 'netmap.mcmaster.ca';
  $dbpw = 'nutbar';
  $dbuser = 'netmap';
}

$DBH = Mysql->connect($dbhost,$db,$dbuser,$dbpw);

unless ($DBH) {
  print STDERR "Could not connect to database. Aborting...\n";
  exit();
}
$where = 'nodes.id=ports.node_id';
if ($ip = shift @ARGV) {
  $where .= " and ip='$ip'";
}
$hRef = getRowsAsHash($DBH,'','nodes,ports',$where,'ip');

foreach $row (@{$hRef}) {
  $ip = $row->{ip};
  $pw = $row->{commStr};
  $port = uc($row->{ifName});
  next if $pw eq '**UNKNOWN**';
  if ($debug) {
    print "Checking $ip:$port...";
  }
  if ($ip ne $oldip) {
    undef $ifHref;
    undef %ifIndex;
    undef $vlHref;
    undef %vlan;
    ($ifHref,$err) = snmpget($ip,$pw,'table','ifName');
    while (($oid,$ifname) = each(%{$ifHref})) {
      if ($oid =~ /$OID{ifName}\.(\d+)$/) {
        $ifIndex{uc($ifname)} = $1;
      }
    }
    ($vlHref,$err) = snmpget($ip,$pw,'table','vmVlan');
    while (($oid,$vlan) = each(%{$vlHref})) {
      if ($oid =~ /$OID{vmVlan}\.(\d+)$/) {
        $vlan{$1} = $vlan;
      }
    }
  }
  if ($row->{vlan} != $vlan{$ifIndex{$port}}) {
    unless ($quiet) {
      print "$row->{sysName} ($ip):$port should be vlan $vlan{$ifIndex{$port}} (was ".$row->{vlan}.")\n";
      if ($interact) {
        print "...update? [y/n] ";
        $ans = <>;
        $update = ($ans =~ /^y/i) ? 1 : 0;
      }
    }
    if ($update) {
      $dj->{vlan} = $vlan{$ifIndex{$port}};
      $dj->{updated_on} = 'MYSQL_FUNC:now()';
      $stat = updateTable($DBH,'ports',"node_id='$row->{node_id}' and ifName='$row->{ifName}'",$dj);
    }
  }
  $oldip = $ip;
}

__END__

=head1 NAME

checkvlan.pl - Verify vlan data recorded in DataJack table

=head1 SYNOPSIS

checkvlan.pl [--quiet] [--i] [SWITCH_IP]

=head1 PARAMETERS

=over 8

=item B<--quiet>

Normally checkvlan.pl will print a single line report for each discrepency it finds and fixes. The B<quiet> option tells it to not print anything.

=item B<--i>

Normally checkvlan.pl will go ahead and fix any discrepencies it finds between what the switch reports and what's recorded in the database, with the switch winning. With the B<--i> option (for interactive) checkvlan.pl will prompt for a response before making the correction.

=item B<--help>

Displays abbreviated help screen and exits.

=item B<--man>

Displays the complete man page and exits.

=back

=head1 DESCRIPTION

checkvlan.pl uses SNMP to query each switch in the DataJack table to find out what vlan each of its interfaces is a member of and compares this with what's recorded in the database.

=back

=cut
