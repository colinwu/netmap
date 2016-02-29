require 'snmp'
$mib = SNMP::MIB.new
module_list = Dir::entries('/usr/share/ruby/snmp/mibs').collect! { |file|
next unless file =~ /\.yaml$/; File::basename(file,'.yaml') }.compact!

module_list.each do |m|
  $mib.load_module(m)
end

hasInvalidPorts = Hash.new
Node.all.each do |n|
  if (n.commStr != '**UNKNOWN**')
    ifList = Array.new
    snmp_ports = n.snmpwalk('IF-MIB::ifName')
    unless snmp_ports.nil?
      snmp_ports.each do |key,val|
        ifList << val.to_s.downcase
      end
      n.ports.each do |p|
        unless ifList.include?(p.ifName.downcase)
          hasInvalidPorts[n.sysName] = (hasInvalidPorts[n.sysName].nil?) ? p.ifName : (hasInvalidPorts[n.sysName] + ":#{p.ifName}")
        end
      end
    end
  end
end

unless hasInvalidPorts.nil?
  hasInvalidPorts.each do |dev,val|
    puts dev + ':' + val
  end
end