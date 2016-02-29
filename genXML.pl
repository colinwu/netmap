#!/usr/local/bin/perl
use Mysql;
require './netmap.ph';

if (-e '/var/run/netmap.pid') {
  $otherpid = `/usr/bin/cat /var/run/netmap.pid`;
  @pslist = `/usr/bin/ps -ef`;
  foreach (@pslist) {
    $other = $_, last if ((split(' ',$_))[1] == $otherpid);
  }
  if ($other) {
    $dbBeingUpdated = 1;
  }
}

$nodeInfoProg = 'http://netman.mcmaster.ca/cgi-bin/nodeinfo.pl';
$DEBUG = $opt_d ? 1 : 0;

$DBH = Mysql->connect("netman.mcmaster.ca",'netmap','netmap','nutbar');
unless ($DBH) {
  print "Could not connect to database. Aborting...\n";
  exit();
}
if ($dbBeingUpdated) {
  print "WARNING: The database is currently being updated. What you see here may not be accurate.\n";
}

open (X, ">map.xml");

$cf = <<DTD;
<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
<!DOCTYPE TOUCHGRAPH_LB [

<!ELEMENT TOUCHGRAPH_LB (NODESET, EDGESET, PARAMETERS)>
<!ELEMENT NODESET (NODE+)>
<!ELEMENT EDGESET (EDGE*)>
<!ELEMENT PARAMETERS (PARAM*)>

<!ELEMENT NODE (NODE_LOCATION?, NODE_LABEL?, NODE_URL?, NODE_HINT?)>

<!ELEMENT NODE_LABEL EMPTY>
<!ELEMENT NODE_URL EMPTY>
<!ELEMENT NODE_HINT EMPTY>

<!ATTLIST TOUCHGRAPH_LB
  version CDATA #REQUIRED >

<!ATTLIST NODE
  nodeID CDATA #REQUIRED >

<!ATTLIST NODE_LOCATION
  visible CDATA #IMPLIED
  x CDATA #IMPLIED
  y CDATA #IMPLIED >

<!ATTLIST NODE_LABEL
  label CDATA #REQUIRED
  shape CDATA #IMPLIED
  backColor CDATA #IMPLIED
  textColor CDATA #IMPLIED
  fontSize CDATA #IMPLIED >

<!ATTLIST NODE_URL
  url CDATA #REQUIRED
  urlIsLocal CDATA #IMPLIED
  urlIsXML CDATA #IMPLIED >

<!ATTLIST NODE_HINT
  hint CDATA #REQUIRED
  height CDATA #IMPLIED
  width CDATA #IMPLIED
  isHTML CDATA #IMPLIED >

<!ELEMENT EDGE EMPTY>

<!ATTLIST EDGE
  fromID CDATA #REQUIRED
  toID CDATA #REQUIRED
  length CDATA #IMPLIED
  color CDATA #IMPLIED
  type CDATA #IMPLIED
  visible CDATA #IMPLIED >

<!ELEMENT PARAM EMPTY>

<!ATTLIST PARAM
  name CDATA #REQUIRED
  value CDATA #REQUIRED >
]>
DTD

$cf .= "<TOUCHGRAPH_LB version=\"1.20\">\n  <NODESET>\n";
$edge = "  <EDGESET>\n";

foreach $Net ('campus') {
  undef %node;

  $n = getNode("Network='campus' or Network='courthouse'");
  @nodeArray = @{$n};
  foreach $node (@nodeArray) {
    ($id = $node->{sysName}) =~ s/\.McMaster\.CA//i;
    $shape = 2;
    $bg = '880000';
    $fontSize = '15';
    $height = '18';
    $vis = 'false';
    $coord = 'x="500" y="0"';
    if ($id =~ /border/io) {
      $coord = 'x="447" y="-31"';
      $shape = 1;
      $bg = '660000';
      $fontSize = '20';
      $vis = 'true';
    }
    elsif ($id =~ /kazoo/io) {
      $coord = 'x="432" y="106"';
      $bg = '660000';
      $vis = 'true';
    }
    elsif ($id =~ /^jhesw$/io) {
      $coord = 'x="508" y="26"';
      $bg = '660000';
      $vis = 'true';
    }
    elsif ($id =~ /^ghsw$/io) {
      $coord = 'x="374" y="12"';
      $bg = '660000';
      $vis = 'true';
    }
    elsif ($id =~ /^mckay-rt$/io) {
      $coord = 'x="508" y="-134"';
      $bg = '660000';
      $vis = 'true';
    }
    elsif ($id =~ /^moulton-rt$/io) {
      $coord = 'x="407" y="-145"';
      $bg = '660000';
      $vis = 'true';
    }
    elsif ($node->{CommStr} eq '**UNKNOWN**') {
      $shape = 3;
      $bg = '666666';
    }
    $cf .= <<DEV;
    <NODE nodeID="$id">
      <NODE_LOCATION visible="$vis" $coord />
      <NODE_LABEL label="$id" shape="$shape" backColor="$bg" textColor="ffff00" fontSize="$fontSize" />
      <NODE_URL url="$nodeInfoProg?node=$node->{sysName}" />
      <NODE_HINT hint="$node->{Platform}<br>$id ($node->{IP})" isHTML='true' width="250" height="100" />
    </NODE>
DEV
    next if ($node->{CommStr} eq '**UNKNOWN**');


    $r = getRel("nodeAId = '$node->{nodeID}'");
    @linkArray = @{$r};
    foreach $link (@linkArray) {
      $tmp = getNode("nodeID='$link->{nodeBId}'");
      $tmpnode = $tmp->[0];
      $linkType = 1;
      $vis = 'false';
      $colour = 'aaaaaa'; #default is grey
      $len = '150';
      ($toId = $tmpnode->{sysName}) =~ s/\.mcmaster.ca//i;
      next unless $tmpnode->{sysName};

      if ($tmpnode->{CommStr} eq '**UNKNOWN**') {
        $linkType = 0;
      }
      if ($toId =~ /^kazoo/io || $toId =~ /^jhesw$/io ||
          $toId =~ /^ghsw$/io) {
        $vis = 'true';
        $len = '200';
      }
      if ($link->{portA} =~ /^Gi/io || $link->{portB} =~ /^Gi/io) {
        $colour = '08f708';  # Green
      }
      elsif ($link->{portA} =~ /^Fa/io || $link->{portB} =~ /^Fa/io) {
        $colour = 'f3f708';  # Yellow
      }

      $edge .= "    <EDGE fromID='$id' toID='$toId' length='$len' color='$colour' type='$linkType' visible='$vis' />\n";
    }
  }
}
$cf .= "  </NODESET>\n";
$edge .= "  </EDGESET>\n";
print X $cf;
print X $edge;
print X <<TAIL;
  <PARAMETERS>
    <PARAM name="offsetX" value="500" />
    <PARAM name="offsetY" value="0" />
    <PARAM name="rotateSB" value="0" />
    <PARAM name="zoomSB" value="-6" />
    <PARAM name="localitySB" value="1" />
  </PARAMETERS>
</TOUCHGRAPH_LB>
TAIL

