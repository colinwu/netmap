#!/usr/local/bin/perl
#
$wucolinsrc = (getpwnam('wucolin'))[7] . '/src';
use Getopt::Long;
use Mysql;
use Net::SNMP;
require "$wucolinsrc/netmap.ph";

GetOptions('v','test','seed=s','net=s','noping','p=s','pipe');
if ($opt_test) {
  $db = 'netmap_development';
  $dbhost = 'localhost';
  $dbuser = 'root';
  $dbpw = 'nutbar';
}
else {
  $db = 'netmap_production';
  $dbhost = 'netmap.mcmaster.ca';
  $dbuser = 'netmap';
  $dbpw = 'nutbar';
}
$DBH = Mysql->connect($dbhost,$db,$dbuser,$dbpw);
unless ($DBH) {
  Fatal ("Could not connect to database.");
}

chomp($target = shift);
if (($target =~ /^[0-9a-f]{12}$/io) ||  # Is it a MAC address
    ($target =~ /^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$/io) ||
    ($target =~ /^[0-9a-f]{4}\.[0-9a-f]{4}\.[0-9a-f]{4}$/io)) {
  ($targetHW = $target) =~ s/[:\.]//g;
  $targetHW =~ s/^/0x/ unless $targetHW =~ /^0x/;
}
elsif ($target =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
  $targetIP = $target;
}
else {
  $targetIP = join('.',unpack('C4',(gethostbyname($target))[4]));
}
$opt_p = 'icmp' unless $opt_p;
unless (grep(/^$opt_p$/,('icmp','udp','tcp'))) {
  $opt_p = 'icmp';
}
if (!$opt_noping && ($> != 0 && $opt_p eq 'icmp')) {
  $opt_noping = 1;
  print STDERR "WARNING: Only root can do icmp ping.";
}

$DEBUG = $opt_v ? 1 : 0;
@networks = ('campus','cishosts','maconline','fhs','dtc');
$seed = {'campus' => '130.113.69.5',  'maconline' => '130.113.69.36', 'cishosts' => '130.113.109.196', 'fhs' => '130.113.45.3'};

# default network to use is 'campus'
if ($opt_net) {
  unless (grep(/^$opt_net$/i, @networks)) {
    print STDERR "$opt_net is not a recognized network. Valid values are 'campus', 'dtc' or 'maconline'. Aborting.\n";
    exit(1);
  }
  $Net = lc $opt_net;
}
else {
  $Net = 'campus';
}

# See if the seed or root device is already in the database
$root{ip} = $opt_seed ? $opt_seed : $seed->{$Net};
$results = getNode("IP='$root{ip}'");
if (!$results->[0]->{sysName}) {
  # Something seriously wrong if we can't find the root node
  Fatal ("ERROR: Root router not found!");
}
else {
  %root = %{$results->[0]};
}

%node = %root;

if ($targetHW) {
  ($targetIP,$Router,$ifIndex) = gethostbymac($targetHW);
  if (!$targetIP && !$opt_noping && !$>) {
    Fatal ("Can't get IP address for $targetHW. Aborting.");
  }
}
if ($targetIP) {

  # Do a ping if we're root.
  if (!$opt_noping && !$>) {
    use Net::Ping;
    $pingsession = Net::Ping->new($opt_p,2);
    if (!$pingsession->ping($targetIP)) {
      debug ("$targetIP is not responding to ping.");
    }
  }
  # The seed device should be a router so check it for a route to the target net
  ($targetHW,$Router,$ifIndex) = findRouter($targetIP,$node{sysName});
}
else {
  Fatal ("Can't figure out what you're looking for. You entered ($target)");
}
$result = getNode("sysName='$Router' and commStr <> '**UNKNOWN**'");
$pw = $result->[0]->{commStr};
@mac = unpack('x2a2a2a2a2a2a2',$targetHW);
$hwStr = join('.',hex($mac[0]),hex($mac[1]),hex($mac[2]),hex($mac[3]),hex($mac[4]),hex($mac[5]));
($ifIndex,$vlan) = findPhysInt($Router,$pw,$ifIndex,$hwStr);

# At this point $Router = sysName of router, $ifIndex = index number of physical
# interface the subnet is connected to and $hwStr = MAC address of IP in
# dotted-decimal notation; e.g.0.3.186.18.246.136. This is how MAC address is
# most often represented in returned OID strings. We also know what vlan the
# target is in.
@neighbours = findNeighbour($Router,$ifIndex);
push(@nodelist, "$Router:$pw:$ifIndex:$hwStr:$vlan");
$BeenThere{$Router} = 1;
push(@searchlist, @neighbours) if @neighbours;

while (@searchlist) {
  ($device,$pw) = split(':',shift @searchlist);
  last if $device eq 'END';
  next if ($BeenThere{$device} || (($pw eq '**UNKNOWN**') && @searchlist));
#  $result = getNode("sysname='$device'");
  debug ("checking node $device");
#  $pw = $result->[0]->{CommStr};
  if ($pw eq '**UNKNOWN**') {
    push (@nodelist, "$device:$pw:UNKNOWN:$hwStr:$vlan");
    last;
  }
  $ifIndex = findCAM($device,$pw,$hwStr,$vlan);
  unless ($ifIndex) {
    push (@nodelist, "$device:$pw:UNKNOWN:$hwStr:$vlan");
    last;
  }
  @neighbours = findNeighbour($device,$ifIndex);
  push (@nodelist, "$device:$pw:$ifIndex:$hwStr:$vlan");
  if (!@neighbours && @searchlist) {
    pop (@nodelist);
  }
  else {
    push @searchlist,@neighbours;
  }
  $BeenThere{$device} = 1;
}

print "Path to $targetIP with MAC address $targetHW:\n";
foreach $node (@nodelist) {
  ($device,$pw,$ifIndex,$hwStr,$vlan) = split(':',$node);
  if (!$opt_pipe) {
    $n = getNode("sysName = '$device'");
    $ip = $n->[0]->{ip};
    ($ifName,$error) = snmp($ip,$pw,'element',"ifName.$ifIndex");
    if ($error) {
      print "- $device on interface UNKNOWN\n";
    }
    else {
      print "- $device on interface $ifName\n";
    }
  }
  else {
    print "$targetIP:$targetHW:$device:$ifIndex:$vlan\n";
  }
}


#############################  Functions #############################
# Fatal exit
sub Fatal {
  my $msg = shift @_;
  print $msg,"\n\n";
  exit(1) if $opt_pipe;
  print "Do you want to file a report to the developer? ";
  my $ans = <>;
  if ($ans =~ /y/io) {
    my $fromID = (getpwuid($<))[0];
    open (M, "| /usr/lib/sendmail -t");
    print M "From: $fromID\n";
    print M "To: wucolin\@mcmaster.ca\n";
    print M "Subject: Fatal report from tracker\n\n";
    print M "$msg\n\n";
    while (@_FatalReport) {
      print M shift @_FatalReport,"\n";
    }
    close M;
  }
  exit(1);
}

# Sort list of routes by their netmask
sub sortByMask {
  my $M1 = (split(':',$a))[0];
  my $M2 = (split(':',$b))[0];
  my @A = split('\.',$M1);
  my @B = split('\.',$M2);
  my $m1 = $A[0]*256**3 + $A[1]*256**2 + $A[2]*256 + $A[3];
  my $m2 = $B[0]*256**3 + $B[1]*256**2 + $B[2]*256 + $B[3];
  return ($m1 <=> $m2);
}

#############################
# Given an IP address returns its hardware address, the router and interface
# that the subnet is directly connected to.
sub findRouter {
  my ($ip, $device) = @_;
  my ($hw, $netHref, $error, $maskHref, $nodeid);
  my @BeenThere;

  my $binTarget = pack('C4',split('\.',$ip));
  debug("findRouter...");
  while ($hw !~ /^0x[0-9a-f]+/) {
  # haven't found a hardware address yet
  # Need a better way to keep from searching the entire Internet...

    next if grep(/^$device$/, @BeenThere);
    push (@BeenThere, $device);

  # Retrieve SNMP community string
    my $n = getNode("sysname='$device' and commStr <> '**UNKNOWN**'");
    if ($n->[0]->{commStr}) {
      $devIP = $n->[0]->{ip};
      $pw = $n->[0]->{commStr};
    }
    else {
      Fatal ("findRouter: Can't retrieve community string for $device. Aborting");
    }
    debug("Checking $device ($pw) for route...");
  # First figure out if the target network is on this device
    undef my @localNet;
    undef my @remoteNet;
    ($netHref, $error) = snmp($devIP,$pw,'table','ipRouteType');
    while (($oid,$value) = each %{$netHref}) {
      $oid =~ /^\.{0,1}$OID{'ipRouteType'}\.(.+)$/;
      $net = $1;
      push(@localNet, $net) if $value == 3;
      push(@remoteNet, $net) if $value == 4;
    }
  # Grab the net mask for all routes
    ($maskHref, $error) = snmp($devIP,$pw,'table','ipRouteMask');
    %maskHash = %{$maskHref};

  # See if the target network is a local route (directly connected)
    undef @routeList;
    foreach $net (@localNet) {
      $mask = $maskHash{"$OID{ipRouteMask}.$net"};
      $binmask = pack('C4',split('\.',$mask));
      $binnet = pack('C4',split('\.',$net));
      if (($binTarget & $binmask) eq $binnet) {
    # found one.
    # but is it a real interface?
        ($ifIndex,$error) = snmp($devIP,$pw,'element',"ipRouteIfIndex.$net");
        ($iftype, $error) = snmp($devIP,$pw,'element',"ifType.$ifIndex");
        next if $iftype == 1;
        debug("findRouter: Found a local route for $net ($mask) on ifIndex = $ifIndex");
        push(@routeList,"$mask:$ifIndex");
      }
    }

  # If no directly connected route ...
    unless (@routeList) {
      foreach $net (@remoteNet) {
        $mask = $maskHash{"$OID{ipRouteMask}.$net"};
        $binmask = pack('C4',split('\.',$mask));
        $binnet = pack('C4',split('\.',$net));
        if (($binTarget & $binmask) eq $binnet) {
          ($gw,$error) = snmp($devIP,$pw,'element',"ipRouteNextHop.$net");
          debug("Found a possible gateway for $ip at $gw");
          push (@routeList, "$mask:$gw");
        }
      }
    }

  # Let's see if we found any route to the target IP
    if (@routeList) {
      ($mask,$var) = split(':',(sort sortByMask @routeList)[-1]);
      if ($var =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) { # a gateway
        $nodeid = getidfromip($var);
        if ($nodeid) {
          $n = getNode("id='$nodeid'");
          $device = $n->[0]->{sysName};
          debug ("Preferred gateway is: $device ($ip)");
        }
        else {
          return ($hw,'',0);
        }
      }
      else {
        $ifIndex = $var;
        ($binhw,$error) = snmp($devIP,$pw,'element',"ipNetToMediaPhysAddress.$ifIndex.$ip");
        $hw = "0x" . unpack('H12',$binhw);
        debug ("$ip ($hw) found on $device, ifIndex = $ifIndex (" .
                (snmp($device,$pw,'element',"ifName.$ifIndex"))[0] . ")");
#        ($sysname,$error) = snmp($device,$pw,'element',"sysName.0");
#        $sysname =~ s/^([^.]+).*$/$1/;
        return ($hw,$device,$ifIndex);
      }
    }
    else {
      print "Can't find a route for $ip.";
      exit(1);
    }
  }
}

#############################
# Given an ifIndex that may point to a virtual interface (like a vlan port)
# find the physical interface associated with the virtual interface
sub findPhysInt {
  my ($router, $pw, $if, $macaddr) = @_;
 # $device is dotted decimal IP addr
 # $ifnum is integer number
 # $pw is a string
 # $macaddr is dotted decimal MAC addr

  my ($oid, $vif, $error, $ifType, $vlanStr, $ifHref, $fdPort,$port, $device);
  debug("findPhysInt...");
  $tmp = getNode("sysName='$router'");
  $device = $tmp->[0]->{ip};
  unless ($pw =~ /\@\d+$/) {
    ($ifType, $error) = snmp($device,$pw,'element',"ifType.$if");
    debug("findPhysInt:int $if on $device is type $ifType");
    if ($ifType == 53) {
      ($vlanStr,$error) = snmp($device,$pw,'element',"ifName.$if");
      $vlan = $1 if $vlanStr =~ /^v[^0-9]+(\d+)$/i;
      $pw = "$pw\@$vlan" unless $pw =~ /\@\d+$/;
      debug("findPhysInt:ifIndex $if is in vlan $vlan");
    }
    else {
      return ($if,1);
    }
  }
  ($fdPort,$error) = snmp($device,$pw,'element',"dot1dTpFdbPort.$macaddr");
  debug("findPhysInt:dot1dTpFdbPort.$macaddr = $fdPort");
  ($port,$error) = snmp($device,$pw,'element',"dot1dBasePortIfIndex.$fdPort");
  debug("findPhysInt:dot1dBasePortIfIndex.$fdPort = $port");
  ($ifType, $error) = snmp($device,$pw,'element',"ifType.$port");
  debug("findPhysInt:ifType.$port = $ifType");
  if ($ifType == 53) {
    ($ifHref, $error) = snmp($device,$pw,'table',"pagpGroupIfIndex");
    while (($oid,$vif) = each %{$ifHref}) {
      next unless $vif == $port;
      $physif = $1 if $oid =~ /\.(\d+)$/;
      debug ("findPhysInt:Physical ifIndex = $physif");
      ($vlanStr,$error) = snmp($device,$pw,'element',"ifName.$physif");
      $vlan = $1 if $vlanStr =~ /^v.+(\d+)$/;
#      $pw = "$pw\@$vlan" unless $pw =~ /\@\d+$/;
      last;
    }
  }
  else {
    $physif = $port;
  }
  return ($physif, $vlan);
}

#############################
# findNeighbours (DEVICE, IFINDEX)
sub findNeighbour {
  my ($Router,$ifIndex) = @_;
  my $i;
  my @neighbours;
  my $error;
  my $result;
  my $myPort;

  debug("findNeighbour: Looking for neighbours of $Router on ifindex=$ifIndex");
  my $n = getNode("sysName='$Router' and commStr <> '**UNKNOWN**'");
  my $device = $n->[0]->{ip};
  my $pw = $n->[0]->{commStr};
  my $nodeID = $n->[0]->{id};

  undef $result;
  ($myPort,$error) = snmp($device,$pw,'element',"ifName.$ifIndex");
  if ($error) {
    debug ("WARNING: $Router does not have SNMP enabled.");
    return ();
  }
  $result = getLink($nodeID,$myPort);
  if ($result) {
    foreach $i (@{$result}) {
      if ($i->{nodeAId} == $nodeID) {
        $n = getNode("id='$i->{nodeBId}'");
        foreach $node (@{$n}) {
          push (@neighbours,"$node->{sysName}:$node->{commStr}");
        }
      }
      else {
        $n = getNode("id='$i->{nodeAId}'");
        foreach $node (@{$n}) {
          push (@neighbours,"$node->{sysName}:$node->{commStr}");
        }
      }
    }
  }
  else {
#    $myPort =~ s/Fa/FastEthernet/ if $myPort =~ /Fa\d/;
#    $myPort =~ s/Gi/GigabitEthernet/ if $myPort =~ /Gi\d/;
    @neighbours = ('END');
  }
  return (@neighbours);
}
#############################
# Given a device name or IP address, snmp community string and a MAC addr string
# (in dotted decimal notation), find the CAM entry for the MAC addr on the
# device.
#
# Returns: ifIndex of physical interface on device.
#
# ifIndex = findCAM (device, commstr, hwstr, vlan);
sub findCAM {
  my ($device, $pw, $hwstr, $vlan) = @_;
  my ($IfIndex, $error, $temp, $val, $oid, $n, $ip);
  debug("findCAM: $device, $pw, $vlan, $hwstr");
  for (my $i = 0; $i < 5; $i++) {
    $n = getNode("sysName = '$device'");
    $ip = $n->[0]->{ip};
    ($temp, $error) = snmp($ip,"$pw\@$vlan",'element',"dot1dTpFdbPort.$hwstr");
    if ($temp) {
      ($ifIndex, $error) = snmp($ip,"$pw\@$vlan",'element',"dot1dBasePortIfIndex.$temp");
      ($temp, $error) = snmp($device,$pw,'element',"ifType.$ifIndex");
      if ($temp == 53) {
        ($pagpGrpIfIndexHref, $error) = snmp($ip,$pw,'table','pagpGroupIfIndex');
        while (($oid,$val) = each %{$pagpGrpIfIndexHref}) {
          if ($val == $ifIndex) {
            $oid =~ /\.(\d+)$/;
            $ifIndex = $1;
          }
        }
      }
      debug("findCAM: Found MAC addr $hwstr on ifIndex=$ifIndex");
      return $ifIndex;
    }
    else {
      debug ("findCAM: Couldn't find a CAM entry on $device. Pinging...");
      use Net::Ping;
      $pingsession = Net::Ping->new($opt_p);
      unless ($pingsession->ping($targetIP)) {
      #  Fatal ("findCAM: Unable to retrieve CAM data for $hwstr from $device.");
        return();
      }
    }
  }
}


#############################
# Given a MAC address find the associated IP address
#
# Returns: IP address in dotted decimal notation
sub gethostbymac {
  my $MAC = shift @_;
  $MAC =~ tr/A-F/a-f/;
  my ($router,$oid,$hw);
  debug ("Looking for IP address for $MAC");
  my $n = getNode("Capability & 1 and CommStr <> '**UNKNOWN**'");
  foreach $router (@{$n}) {
    my $pw = $router->{CommStr};
    my $ip = $router->{IP};
    debug ("Checking router $ip");
    my ($hwHref,$error) = snmp($ip,$pw,'table',"ipNetToMediaPhysAddress");
    unless ($error) {
      while (($oid,$binhw) = each %{$hwHref}) {
        $hw = "0x" . unpack('H12',$binhw);
        if ($hw eq $MAC) {
          $oid =~ /(\d+)\.(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/;
          my $ifIndex = $1;
          my $targetip = $2;
          my ($sysname,$error) = snmp($ip,$pw,'element',"sysName.0");
          $sysname =~ s/^([^.]+).*$/$1/;
          return ($targetip,$sysname,$ifIndex);
        }
      }
    }
    else {
      debug ($error);
    }
  }
  # if we reached this point we didn't get a match
  debug ("Did not find IP address for $MAC");
  return ('','','');
}
