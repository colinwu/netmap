require 'snmp'

Node.find( :all, :conditions => "commStr != '**UNKNOWN**'" ).each do |n|
  n.platform = n.get_platform
  n.save
end