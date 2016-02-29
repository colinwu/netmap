#!/usr/bin/env RAILS_ENV=production ./script/runner
#
# Expects .csv file exported from spreadsheets with following format:
#
# Switch: XXXSWYYY
# PORT,LABEL,PORT,LABEL,PORT,LABEL,...
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
while (ARGV.length >= 1)
  file = ARGV.shift
  f = open(file, "r")

  while (a = f.gets)
    a.chomp!
    if (a =~ /^Switch:/)
      stuff = a.split(',')
      node = (stuff[0].split)[1]
      n = Node.find_by_sysName node
      if n.nil?
        puts "Switch node not found in database. Please add it first."
      else
        n.get_ifindex
      end
      short_name = node.match(/^(.+)sw/i)[1]
      puts n.inspect
      next
    end

    unless (n.nil?)
      bldg = Building.find_by_short_name short_name
      while bldg.nil?
        print "Please tell me what building this switch is in; e.g. BSB, JHE, or STOP to abort entries for this switch: "
        short_name = gets
        short_name.chomp!
        if short_name == 'STOP'
          break
        else
          bldg = Building.find_by_short_name short_name
        end
      end
      if bldg.nil?
        next
      else
        if (a =~ /^Fa/ || a =~ /^Gi/)
          stuff = a.split(',')
          idx = 0
          while (idx < stuff.length)
            port = stuff[idx]
            label = stuff[idx+1]
            p = n.ports.find_by_ifName port
            p.label = label
            p.building_id = bldg.id
            puts p.inspect
            p.save
            idx += 2
          end
        end
      end
    end
  end
end