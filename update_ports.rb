if Rails.env == 'production'
  log = Logger.new('log/netmap.log', shift_age = 'monthly')
else
  logfile = File.open('log/netmap-dev.log', File::WRONLY | File::APPEND | File::CREAT)
  log = Logger.new(logfile)
end
log.formatter = proc {|severity, datetime, progname, msg| Time.now.to_s + ": #{msg}\n" }

require 'snmp'
::ApplicationController

Node.where('commStr <> "**UNKNOWN**"').each do |dev|
  vlanlist = dev.snmpwalk('vmVlan')
  resp = dev.snmpwalk('ifName')
  resp.each do |key,val|
    ifName = val.to_s
    ifIndex = (/\.(\d+)$/.match(key))[1].to_i
    vlanoid = $mib.oid('vmVlan').to_s + ".#{ifIndex}"
    if vlanlist.has_key?(vlanoid)
      vlan = vlanlist[vlanoid].to_s
    else
      vlan = 0
    end
    port = Port.where(["node_id=? and ifName=?",dev.id,ifName]).first
    if port.nil?
      port = Port.create(:ifName => ifName, :node_id => dev.id, :ifIndex => ifIndex, :vlan => vlan)
    else
      port.update_attributes(:ifIndex => ifIndex, :vlan => vlan)
    end
  end
end
