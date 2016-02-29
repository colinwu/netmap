#!/usr/bin/env RAILS_ENV=production ./script/runner
#
# Expects .csv file exported from spreadsheets with following format:
#
# Switch Name: XXXSWYYY [IP ADDRESS: w.x.y.z]
# PORT,LABEL,VLAN,COMMENT
# ...
#
# We try to figure out the building name from the switch name where switches are expected
# to be named as building short name followed by 'SW' followed by location;
# e.g. BSBSW2N-A where 'BSB' is the building short name
#
# To run in development environment use
#    /usr/bin/env RAILS_ENV=development script/runner *.csv
#
stuff = Array.new
while ARGV.length >= 1
  file = ARGV.shift
  f = open(file, "r")

  while (a = f.gets)
    a.chomp!
    if (a =~ /^Switch Name:/i)
      node = a.match(/Switch Name: ([^\s]+)/i)[1]
      n = Node.find_by_sysName node
      short_name = node.match(/^(.+)sw/i)[1]
      if n.nil?
        puts "Switch #{node} does not exist in the database. Please add it first."
      else
        n.get_ifindex
      end
      puts n.inspect
      next
    end

    unless (n.nil?)
      if (short_name =~ /\d+/)
        bldg = Building.find_by_bldg_number short_name
      else
        bldg = Building.find_by_short_name short_name
      end
      while bldg.nil?
        print "Please tell me what building this switch is in; e.g. BSB, JHE, or NEXT to abort entries for this switch: "
        short_name = gets
        short_name.chomp!
        if short_name == 'NEXT'
          break
        else
          bldg = Building.find_by_short_name short_name
        end
      end
      if bldg.nil?
        next
      else
        if (a =~ /^Fa/i || a =~ /^Gi/i)
          stuff = a.split(',')
          p = n.ports.find_by_ifName stuff[0]
          p.label = stuff[1]
          p.vlan = stuff[2]
          p.comment = (stuff[3].nil? or stuff[3].length == 0) ? '-': stuff[3]
          p.building_id = bldg.id
          puts p.inspect
          p.save
        end
      end
    end
  end
end