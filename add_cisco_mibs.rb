#!/usr/bin/ruby
require 'snmp'
Dir.chdir '/home/wucolin/src/tracker/OIDs'
current_list = Dir.entries('/usr/share/snmp/mibs')
Dir.foreach('.') do |oid_file|
  next if oid_file =~ /^\./ || oid_file =~ /~$/ || oid_file !~ /\.oid$/
  base = File.basename(oid_file, '.oid')
  yaml_file = base + '.yaml'
  next if current_list.include?(yaml_file)
  puts "Processing: #{oid_file}..."
  f = File.new(oid_file,'r')
  y = File.new("/usr/share/snmp/mibs/#{yaml_file}",'w')
  y.puts '---'
  f.each_line do |line|
    next if line =~ /^#/ || line =~ /^\s*$/
    line.gsub!(/"\s+"/,': ')
    line.gsub!(/"/,'')
    y.puts line
  end
  f.close
  y.close
end
