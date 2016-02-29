#!/usr/bin/env ./script/runner -e production
stuff = Array.new
while (gets)
  chomp!
  stuff = $_.split(',')
  sysName = (stuff[1].split('.'))[0]
  n = Node.find_by_sysName sysName
  if !n.nil?
    p = n.ports.find_by_ifName stuff[2]
    if !p.nil?
      puts "#{sysName}:#{stuff[2]} => #{p.label}"
    else
      puts "#{sysName}:#{stuff[2]} is not labeled"
    end
  else
    puts "#{sysName}:#{stuff[2]} is not in the database"
  end
end
