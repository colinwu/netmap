require 'snmp'
::ApplicationController

Node.where('commStr <> "**UNKNOWN**"').each do |dev|
  $log.debug("Device #{dev.ip}, pw = #{dev.commStr}")
  vlanlist = dev.snmpwalk('vmVlan')
  resp = dev.snmpwalk('ifName')
  resp.each do |key,val|
    ifName = val.to_s
    ifIndex = (/\.(\d+)$/.match(key))[1].to_i
    if vlanlist.has_key?("CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}")
      vlan = vlanlist["CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}"].to_s    else
      vlan = 0
    end
    port = Port.where(["node_id=? and ifName=?",dev.id,ifName]).first
    if port.nil?
      port = Port.create(:ifName => ifName, :node_id => dev.id, :ifIndex => ifIndex, :vlan => vlan)
      $log.info("#{dev.ip} #{port.ifName} added.")
    else
      port.update_attributes(:ifIndex => ifIndex, :vlan => vlan)
      $log.info("#{dev.ip} #{port.ifName} updated.")
    end
  end
end
