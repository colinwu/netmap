for n in (ARGV)
  node = Node.find_by_sysName n
  node.ports.each do |p|
    if p.ifName =~ /^Fa(.+)/
      newp = Port.find :first, :conditions => "ifName = 'Gi#{$1}' and node_id = #{node.id}"
      unless newp.nil?
        puts "old = #{p.ifName}, new = #{newp.ifName}"
        newp.update_attributes({:label => p.label, :building_id => p.building_id, :comment => p.comment})
      else
        puts "No corresponding new port for #{p.ifName}"
      end
    end
  end
end