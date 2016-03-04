#!/usr/bin/env RAILS_ENV=production ./script/runner
require 'snmp'

Node.where("(capability & 1) = 1 and commStr <> '**UNKNOWN**'").each do |n|

  ifNameCache = Hash.new
  new = 0
  old = 0
  router = n.sysName

  arplist = n.snmpwalk("ipNetToMediaPhysAddress")
  arplist.each do |key,val|
    m = /\.(\d+)\.(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/.match(key)
    if !m.nil?
      ifIndex = m[1]
      ip = m[2]
      arpval = val
      hexmac = arpval.unpack("h2h2h2h2h2h2").join('')
      if (ifNameCache[ifIndex].nil?)
        ifName = n.snmpget("ifName.#{ifIndex}")
        ifNameCache[ifIndex] = ifName
      else
        ifName = ifNameCache[ifIndex]
      end
#      puts("#{ip} <0x#{hexmac}> on #{router}:#{ifName}")
      a = Arpcache.where("ip='#{ip}' and mac='#{hexmac}'").first
      if (a.nil?)
        a = Arpcache.create( :ip => ip, :mac => hexmac, :router => router, :if => ifName )
        new += 1
      else
        a.ip = ip
        a.mac = hexmac
        a.router = router
        a.if = ifName
        a.updated_at = Time.now
        a.save
        old += 1
      end
    end
  end
  puts("Found #{new} new and #{old} old entries")
end
