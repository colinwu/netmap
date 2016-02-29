require 'MyDBI.ph';
use Net::SNMP;
package netmap;
sub main::debug {
  $, = "\n";
  print (@_,'') if $main::DEBUG;
  $, = '';
  push (@main::_FatalReport,@_);
}


# getNode($condition)
#   $condition is a valid MySql "where" clause.
# Returns a reference to an array of hashes where the key is the field name
# and the value is the data
#

sub main::getNode {
  my ($condition) = @_;
  return (main::getRowsAsHash($main::DBH,'*','nodes', $condition));
}

# getLink($devA,$portA,$devB,$portB)
#
# Returns a reference to an array of hashes where the key is the field name
# and the value is the data
#
sub main::getLink {
  my ($devA,$portA,$devB,$portB) = @_;
  my ($tmpHRef, $nodeHRef, $returnHref);
  my ($porta_id, $portb_id, $tmp);

  $porta_id = (main::getRow($main::DBH,'*', 'ports', "node_id = $devA and ifName = '$portA'"))->{id};
  if ($devB && $portB) {
    $portb_id = (main::getRow($main::DBH,'*', 'ports', "node_id = $devB and ifName = '$portB'"))->{id};
  }
  undef $tmp;
  if ($porta_id && $portb_id) {
#    $tmpHRef = main::getRowsAsHash($main::DBH,'*', 'links', "(port_a_id = $porta_id and port_b_id = $portb_id) or (port_a_id = $portb_id and port_b_id = $porta_id)");
    $tmpHRef = main::getRowsAsHash($main::DBH,'*', 'links', "(port_a_id = $porta_id and port_b_id = $portb_id)");
    if (!$tmpHRef) {
      return undef;
    }
  }
  elsif ($porta_id && !$portb_id) {
    # Only one device-port pair specified, so could be many matches
#    $tmpHRef = main::getRowsAsHash($main::DBH,'*', 'links', "(port_a_id = $porta_id or port_b_id = $porta_id)");
    $tmpHRef = main::getRowsAsHash($main::DBH,'*', 'links', "(port_a_id = $porta_id)");
    if (!$tmpHRef) {
      return undef;
    }
  }
  else {
    return undef;
  }
  foreach $row (@{$tmpHRef}) {
    $tmp->{id} = $row->{id};
    $nodeHRef = main::getRow($main::DBH,'*', 'ports,nodes',
          "ports.id = $row->{port_a_id} and node_id = nodes.id");
    $tmp->{nodeAId} = $nodeHRef->{node_id};
    $tmp->{portA} = $nodeHRef->{ifName};
    $nodeHRef = main::getRow($main::DBH,'*', 'ports,nodes',
          "ports.id = $row->{port_b_id} and node_id = nodes.id");
    $tmp->{nodeBId} = $nodeHRef->{node_id};
    $tmp->{portB} = $nodeHRef->{ifName};
    push @{$returnHref}, $tmp;
  }
  return $returnHref;
}

# updateNode($nodeHref)
#   $nodeHref is a reference to a hash containing the node data where the key
#       is the field name and the value is the data to be stored
#   If the node already exists (entry with same IP address) the data is updated
#   otherwise it's inserted as a new record
# Returns node ID of record just updated or inserted
#
sub main::updateNode {
  my $nodeHref = shift @_;
  my $updateCondition = shift @_;
  my %tmp, $q, $sth, $result;
  my $colstring, $valstring;
  # check if the node sysname is in the database
  my @colkeys = keys %{$nodeHref};
  $result = main::getNode("sysName ='$nodeHref->{sysName}'");
  %tmp = %{$result->[0]};
  if ($tmp{ip}) {
    # we're doing an update
    $q = "update nodes set updated_on = now(),";
    while ($col = pop @colkeys) {
      next if $col =~ /updated_on/io;
      $q .= " $col = '$nodeHref->{$col}'";
      $q .= "," if (@colkeys);
    }
    $q .= " where ";
    $q .= $updatecondition ? $updatecondition : "sysName='$nodeHref->{sysName}'";
  }
  else {
    $valstring = 'now()';
    $colstring = 'updated_on';
    while ($col = pop @colkeys) {
      next if $col =~ /updated_on/io;
      $colstring = join(',',$colstring,$col);
      $valstring = join(',',$valstring,"'$nodeHref->{$col}'");
    }
    $q = "insert into nodes ($colstring) values ($valstring);";
  }
  main::debug ("******************") if $nodeHref->{sysName} =~ /GHSW\./o;
  main::debug ("updateNode: $q");
  main::debug ("******************") if $nodeHref->{sysName} =~ /GHSW\./o;
  $sth = $main::DBH->query($q);
  $result = main::getNode("sysName='$nodeHref->{sysName}'");
  %tmp = %{$result->[0]};
  return ($tmp{id});
}

# updateRel($relHref)
#
#   Relationship is either updated or inserted. All fields of a relationship
#     must match for it to be considered as existing. Only the "updated_on" field
#     is updated.
# Returns: Relationship record ID.
#
sub main::updateLink {
  my ($devA,$portA,$devB,$portB) = @_;
  my ($porta_id,$portb_id,$tmpHash);
  my ($data);

  return (undef) unless ($devA > 0 && $devB > 0 && $portA && $portB);

  $porta_id = main::updatePort($devA,$portA);
  $portb_id = main::updatePort($devB,$portB);
  $tmpHash = main::getLink($devA,$portA,$devB,$portB);
  if (!$tmpHash) {
    # The link record doesn't exist.
    unless ($porta_id && $portb_id) {
      return undef;
    }
    $data->{port_a_id} = $porta_id;
    $data->{port_b_id} = $portb_id;
    $where = '';
  }
  else {
    $where = "id = $tmpHash->[0]->{id}";
  }
  $data->{updated_on} = 'MYSQL_FUNC:now()';

  return (main::updateTable($main::DBH,'links',$where,$data));
}

# updatePort ($dev,$port,$desc,$vlan)
#
# $dev and $port are required and uniquely specifis the port record
# Returns id of ports record or undef on error
sub main::updatePort {
  my ($dev,$port,$desc,$vlan) = @_;
  my $data;
  my $ifindex;

  my $tmpHash = main::getRow($main::DBH,'*','nodes',"id = $dev");
  my $ip = $tmpHash->{ip};
  my $pw = $tmpHash->{commStr};

  my ($tmpHref,$error) = main::snmpget($ip,$pw,'table','ifName');
  foreach $oid (keys %{$tmpHref}) {
    if ($tmpHref->{$oid} =~ /^$port$/i) {
      $ifindex = $oid =~ /^$main::OID{'ifName'}\.(\d+)$/i ? $1 : undef;
    }
  }

  $data->{node_id} = $dev;
  $data->{ifName} = $port;
  $data->{comment} = $desc if $desc;
  $data->{ifIndex} = $ifindex;
  $data->{vlan} = $vlan if $vlan;
  $data->{updated_on} = 'MYSQL_FUNC:now()';
  if (main::updateTable($main::DBH,'ports',"node_id = $dev and ifName = '$port'",$data)) {
    $port_id = (main::getRow($main::DBH,'*','ports',"node_id = $dev and ifName = '$port'"))->{id};
#     main::updateTable($main::DBH,'port_as',"port_id = $port_id",{'port_id' => $port_id, 'updated_on' => 'MYSQL_FUNC:now()'});
#     main::updateTable($main::DBH,'port_bs',"port_id = $port_id",{'port_id' => $port_id, 'updated_on' => 'MYSQL_FUNC:now()'});
    return $port_id;
  }
  else {
    return undef;
  }
}

# updateJack ($bldg,$switch,$port,$label,$vlan,$comment)
#
# Returns jacks.id
sub main::updateJack {
  my ($bldg,$dev,$port,$label,$vlan,$comment) = @_;
  my ($tmpHref,$data,$node_id);

  $tmpHref = main::getNode("sysname='$dev'");
  $node_id = $tmpHref->[0]->{id};
  $port_id = main::updatePort($node_id,$port,'',$vlan);
  $tmpHref = main::getRow($main::DBH,'id','buildings',"short_name='$bldg'");
  $data->{building_id} = $tmpHref->{id};
  $data->{comment} = $comment;
  $data->{label} = $label;
  $data->{updated_on} = 'MYSQL_FUNC:now()';
  if (main::updateTable($main::DBH,'ports',"id='$port_id'",$data)) {
    return (main::getRow($main::DBH,'id','ports',"id='$port_id'"))->{id};
  }
  else {
    return undef;
  }
}


sub main::getARP {
  my $condition = shift @_;
  my ($sth, $i, $a);

  $sth = $main::DBH->query("select * from arptable where $condition");
  if ($sth->numrows) {
    $i = 0;
    while ($i < $sth->numrows) {
      %{$a->[$i]} = $sth->fetchhash;
      $i++;
    }
    return ($a);
  }
  else {
    return (undef);
  }
}

sub main::getMAC {
  my $condition = shift @_;
  my ($sth, $i, $a);

  $sth = $main::DBH->query("select * from mactable where $condition");
  if ($sth->numrows) {
    $i = 0;
    while ($i < $sth->numrows) {
      %{$a->[$i]} = $sth->fetchhash;
      $i++;
    }
    return ($a);
  }
  else {
    return (undef);
  }
}


sub report {
  return unless $main::DEBUG;
  my ($msg,$error,$hostname,$community,$oid) = @_;
  print  <<EOM;
msg:   $msg
error: $error
host:  $hostname
pw:    $community
oid:   $oid

EOM
}

# Read in OIDs for the SNMP module
dbmopen (main::OID,'/usr/local/etc/OIDs/OIDdbm',0444) || die $!;

# Read in custom community strings. Default is public.
if (open(C,'/usr/local/etc/tracker.conf')) {
  while (<C>) {
    chomp;
    ($dev,$commstr) = split;
    $CommStr{$dev} = $commstr;
  }
}
close C;


sub main::snmpget {
  return (&main::snmp(@_));
}

sub main::snmp {
  my ($hostname, $community, $type, $var) = @_;
  my $result;
  my $href;
  my %stuff;
  my $key;
  my ($session, $error) = Net::SNMP->session(
    -hostname  => $hostname,
    -community => $community,
    -port      => 161,
    -version   => 'snmpv1',
    -timeout   => 3,
    -translate => [
        -all => 0,
        -timeticks => 1
                  ]
  );

  if (!defined($session)) {
    report("ERROR creating session",$error,$hostname,$community,$var);
    return ('',$error);
  }
  if ($var =~ /^\.?1\.3\.6\./) {      # e.g. 1.3.6....  do nothing
  } elsif ($main::OID{$var}) {
    $var = $main::OID{$var};
  } else {
    my $savevar = $var;
    my $max = split('\.',$var);
    my $found = 0;
    for ($i = 1; $i <= $max; $i++) {
      $var =~ s/\.\d+$//;
      $found = 1, last if $main::OID{$var};
    }
    $savevar =~ /$var\.(.+)$/;
    $var = "$main::OID{$var}.$1";
  }
  undef %stuff;

  if ($type eq 'table') {
    $oidbase = $var;
    while (1) {
      $href = $session->get_next_request (-varbindlist => [$var]);
      undef %stuff, last unless defined($href);
      $key = (keys %{$href})[0];
      last unless (Net::SNMP::oid_base_match($oidbase,$key));
      $stuff{$key} = $href->{$key};
      $var = $key;
    }
    $result = \%stuff;
  } elsif ($type eq 'element') {
    $result = $session->get_request ( -varbindlist => [$var] );
  } else {
    report("ERROR: don't know what to do with request type $type.",$error,$hostname,$community,$var);
    $session->close;
    return('',$error);
  }
  if (!defined($result)) {
    $error = $session->error();
    if ($error =~ /No response/) {
      report("Warning: Possibly the community string is wrong.",$error,$hostname,$community,$var);
    }
    else {
      report("ERROR retrieving data",$error,$hostname,$community,$var);
      $session->close;
      return('',$error);
    }
  }

  $session->close;

  my $retval;
  if ($type eq 'element') {
    $key = (keys %{$result})[0];
    $retval = $result->{$key};
  }
  else {
    $retval = $result;
  }

  return ($retval, $error);
}


sub main::snmpset {
  my ($host,$pw,$varref) = @_;
  my ($session, $error) = Net::SNMP->session(
    -hostname  => $host,
    -version   => 'snmpv1',
    -community => $pw,
    -port      => 161,
    -timeout   => 3
  );
  my ($var);

  if (!defined($session)) {
    report("ERROR creating session",$error,$host,$pw,$varref);
    $session->close;
    return ('',$error);
  }

  foreach $var (@{$varref}) {
    my ($oid,$type,$val) = split(':',$var);
    $type = "main::$type";
    if ($oid =~ /^\.?1\.3\.6/) {
      $oid =~ s/^\.//;  # already in 1.3.6.... format. Just get rid of leading '.'
    }
    elsif ($main::OID{$oid}) {
      $oid = $main::OID{$oid}; # A name like ifAdminStatus. Convert to 1.3.6....
    }
    else {
      my $savevar = $oid;
      my $max = split('\.',$oid);
      my $found = 0;
      for ($i = 1; $i <= $max; $i++) {
        $oid =~ s/\.\d+$//;
        $found = 1, last if $main::OID{$oid};
      }
      $savevar =~ /$oid\.(.+)$/;
      $oid = "$main::OID{$oid}.$1";
    }
    if (eval($type) && $val) {
      my $result = $session->set_request(
              -varbindlist => [$oid,eval($type),$val]
      );

      if (!defined($result)) {
        report("ERROR: %s.\n", $session->error);
        my $error = $session->error;
        $session->close;
        return('',$error);
      }

      main::debug(sprintf ("snmpset:$oid for host '%s' set to '%s'\n",
        $session->hostname, $result->{$oid})
      );
    }
    else {
      main::debug("snmpset: Unrecognized $type and/or $val\n");
    }
  }
  $session->close;
  return($result,$error);
}

sub main::getidfromip {
  my $ip = shift @_;
  my $sysName;
  my $error;
  foreach $pw ('mac-snmp', 'public', 'csuview') {
    ($sysName,$error) = main::snmpget($ip,$pw,'element','sysName.0');
    last if $sysName;
  }
  $sysName =~ s/^([^.]+).*$/$1/;
  my $n = main::getNode("sysName = '$sysName'");
  if ($n->[0]->{id}) {
    return $n->[0]->{id};
  }
  else {
    return undef;
  }
}
package main;
1;
