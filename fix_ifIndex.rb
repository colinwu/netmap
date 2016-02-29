require 'snmp'
$mib = SNMP::MIB.new
module_list = Dir::entries('/usr/share/ruby/snmp/mibs').collect! { |file|
next unless file =~ /\.yaml$/; File::basename(file,'.yaml') }.compact!
module_list.each do |m|
  $mib.load_module(m)
end

base_oid = $mib.oid('ifName').to_s

Node.find(:all, :conditions => "commStr <> '**UNKNOWN**'").each do |node|
  print "Fixing #{node.sysName}"
  obj = node.snmpwalk('ifName')
  unless obj.nil?
    obj.each do |x|
      print '.'
      index = /#{base_oid}\.(.+)/.match(x[:object_id].to_s)
      ifIndex = index[1]
      p = node.ports.find_by_ifName x[:val].to_s
      if p.nil?
        Port.create(:node_id => node.id, :ifName => x[:val], :ifIndex => ifIndex)
      else
        p.ifIndex = ifIndex
        p.save
      end
    end
  end
  puts ''
end
