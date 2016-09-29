::ApplicationController
require 'snmp'
$log.info("getArpCache started.")
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
      hexmac = arpval.unpack("H2H2H2H2H2H2").join('')
      if (ifNameCache[ifIndex].nil?)
        ifName = n.snmpget("ifName.#{ifIndex}")
        ifNameCache[ifIndex] = ifName
      else
        ifName = ifNameCache[ifIndex]
      end
#      puts("#{ip} <0x#{hexmac}> on #{router}:#{ifName}")
      # Modify the oldest arp entry
      a = Arpcache.where("mac='#{hexmac}'").order(:updated_at).first
      if (a.nil?)
        a = Arpcache.create( :ip => ip, :mac => hexmac, :router => router, :if => ifName, :ifIndex => ifIndex )
        new += 1
      else
        a.ip = ip
        a.mac = hexmac
        a.router = router
        a.if = ifName
        a.ifIndex = ifIndex
        a.updated_at = Time.now
        a.save
        old += 1
      end
    end
  end
  $log.info("Found #{new} new and #{old} old entries on #{router}")
end
