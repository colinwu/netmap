#!/usr/bin/env /home/wucolin/src/netmap-rails/script/runner

cf = <<DTD
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
<TOUCHGRAPH_LB version="1.20">
<NODESET>
DTD

# Node entries
Node.find( :all ).each do |n|
  id = n.sysName
  shape = 2
  bg = '880000'
  fontSize = '15'
  height = '18'
  visble = 'false'
  coord = 'x="500" y="0"'
  if id =~ /border/i
    coord = 'x="447" y="-31"'
    shape = 1
    bg = '660000'
    fontSize = '20'
    visible = 'true'
  elsif id =~ /kazoo/i
    coord = 'x="432" y="106"'
    bg = '660000'
    visible = 'true'
  elsif id =~ /^jhesw$/i
    coord = 'x="508" y="26"'
    bg = '660000'
    visible = 'true'
  elsif id =~ /^ghsw$/i
    coord = 'x="374" y="12"'
    bg = '660000'
    visible = 'true'
  elsif id =~ /^mckay-rt$/i
    coord = 'x="508" y="-134"'
    bg = '660000'
    visible = 'true'
  elsif id =~ /^moulton-rt$/i
    coord = 'x="407" y="-145"'
    bg = '660000'
    visible = 'true'
  elsif id =~ /^ccasw1$/i
    coord = 'x="447" y="-200"'
    bg = '660000'
    visible = 'true'
  elsif n.commStr == '**UNKNOWN**'
    shape = 3
    bg = '666666'
  end
  cf += <<DEV;
  <NODE nodeID="#{id}">
  <NODE_LOCATION visible="#{visible}" #{coord} />
  <NODE_LABEL label="#{id}" shape="#{shape}" backColor="#{bg}" textColor="ffff00" fontSize="#{fontSize}" />
  <NODE_URL url="http://netmap.mcmaster.ca/node?sysname=#{n.sysName}" />
  <NODE_HINT hint="#{n.platform}<br>#{id} (#{n.ip})" isHTML='true' width="250" height="100" />
  </NODE>
DEV
end

cf += "</NODESET>\n"
# Edge (connector) entries using the Link table
edge = "<EDGESET>\n"
ignore = Array.new

Link.find( :all ).each do |link|
  next if link.port_a.nil? or link.port_b.nil?
  next if ignore.member?(link.id)

  nodeA = link.port_a.node
  nodeB = link.port_b.node
  linkType = 1
  visible = 'false'
  colour = 'aaaaaa'
  len = '150'
  if nodeA.commStr == '**UNKNOWN**'
    linkType = 0
  end
  if nodeB.sysName =~ /^kazoo/i || nodeB.sysName =~ /^jhesw$/i || nodeB.sysName =~ /^ghsw$/i || nodeB.sysName =~ /-rt$/i
    visible = 'true'
    len = '200'
  end
  if link.port_a.ifName =~ /^Gi/i || link.port_b.ifName =~ /^Gi/i
    colour = '08f708'
  elsif link.port_a.ifName =~ /^Fa/i || link.port_b.ifName =~ /^Fa/i
    colour = 'f3f708'
  end
  edge += "    <EDGE fromID='#{nodeA.sysName}' toID='#{nodeB.sysName}' length='#{len}' color='#{colour}' type='#{linkType}' visible='#{visible}' />\n"
  ignore << Link.find_by_port_b_id_and_port_a_id( link.port_a_id, link.port_b_id ).id
end


xml = open('map.xml','w')
xml.puts cf
xml.puts edge
xml.puts <<TAIL
</EDGESET>
<PARAMETERS>
<PARAM name="offsetX" value="500" />
<PARAM name="offsetY" value="0" />
<PARAM name="rotateSB" value="0" />
<PARAM name="zoomSB" value="-6" />
<PARAM name="localitySB" value="1" />
</PARAMETERS>
</TOUCHGRAPH_LB>
TAIL
xml.close
