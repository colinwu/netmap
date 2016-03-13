require 'snmp'
::ApplicationController

Node.where('commStr <> "**UNKNOWN**"').each do |dev|
  $log.debug("Device #{dev.ip}, pw = #{dev.commStr}")
  vlanlist = dev.snmpwalk('vmVlan')
  ifLabels = dev.snmpwalk('IF-MIB::ifAlias')
  ifNames = dev.snmpwalk('ifName')
  ifNames.each do |key,val|
    ifName = val.to_s
    ifIndex = (/\.(\d+)$/.match(key))[1].to_i
    if vlanlist.has_key?("CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}")
      vlan = vlanlist["CISCO-VLAN-MEMBERSHIP-MIB::vmVlan.#{ifIndex}"].to_s
    else
      vlan = 0
    end
    label = ifLabels["IF-MIB::ifAlias.#{ifIndex.to_s}"].to_s
    port = Port.where(["node_id=? and ifName=?",dev.id,ifName]).first
    if port.nil?
      port = Port.create(:ifName => ifName, :node_id => dev.id, :ifIndex => ifIndex, :vlan => vlan, :comment => label)
      $log.info("#{dev.ip} #{port.ifName} added.")
    else
      if port.comment.nil? or port.comment.empty? or port.comment == '-'
        port.update_attributes(:ifIndex => ifIndex, :vlan => vlan, :comment => label)
      else
        port.update_attributes(:ifIndex => ifIndex, :vlan => vlan)
      end
      $log.info("#{dev.ip} #{port.ifName} updated.")
    end
  end
end
