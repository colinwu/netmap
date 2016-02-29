#!/usr/bin/env /var/www/netmap/current/script/runner
require 'optparse'
require 'resolv'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: csv2db.rb [options]"

  opts.on("-f", "--file FILE", "Data file in csv format") do |f|
    options[:file] = f
  end
  opts.on("-b", "--bldg [BLDG]", "Specify short building name") do |b|
    options[:bldg] = b
  end
  opts.on('-d', '', 'Debug') do |d|
    options[:debug] = d
  end
end.parse!
# file name is now in options[:file]

if (options[:debug])
  puts "File = #{options[:file]}"
  puts "Bldg = #{options[:bldg]}"
end

unless (bldg = Building.find :first, :conditions => "short_name = '#{options[:bldg]}'")
  puts ("#{options[:bldg]} is not a recognized building name.")
  exit
end
n = Node.new
bldg = Building.new
p = Port.new

f = File.open(options[:file])
f.each do |line|
  puts(line) if (options[:debug])
  if (m = /(.+):(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(\w*)/.match(line))
    ip = m[2]
    sn = m[1]
    bn = m[3]
    puts( "Device = #{sn}, IP = #{ip}" ) if (options[:debug])
    unless (n = Node.find :first, :conditions => "sysName = '#{sn}'")
      unless (name = Resolv.getname(ip))
        puts ("Could not resolve DNS name for #{ip}")
        exit
      end
      sn = /[^.]+/.match(name)[0]
      unless (n = Node.find :first, :conditions => "sysName = '#{sn}'")
        puts ("Could not find node #{sn} with IP address #{ip} in the database.")
        exit
      end
    end
    nodeid = n.id
    puts( "Node ID = #{n.id}") if (options[:debug])
    next
  end
  if (m = /((fa|gi)[^,]*\d),([^,]*),([^,]*),([^,]*),([^,]*)/i.match(line))
    port = m[1]
    label = m[3]
    vlan = m[4]
    comment = m[5]
    puts( "Port = #{port}, Label = #{label}, Comment = #{comment}" ) if (options[:debug])
    if (p = Port.find :first, :conditions => "ifName = '#{port}' and node_id = '#{n.id}'")
      puts( "Found port. ID = #{p.id}" ) if (options[:debug])
      p.label = label
      p.building_id = bldg.id
      p.comment = comment
      p.save
    else
      puts( "Created new port." ) if (options[:debug])
      p = Port.new()
      p.ifName = port
      p.label = label
      p.building_id = bldg.id
      p.node_id = nodeid
      p.comment = comment
      p.save
    end
  end
end