#!/usr/bin/env /home/wucolin/src/netmap-rails/script/runner

require 'net/dns/resolver'
res = Net::DNS::Resolver.new
res.tcp_timeout = 10
res.udp_timeout = 5

Arpcache.find( :all, :conditions => "updated_on < date_sub(now(), INTERVAL 1 YEAR)" ).each do |arp|
  begin
    p = res.search(arp.ip.to_s)
  rescue
    puts "Resolver error: #{$!}"
    retry
  end
  if p.answer.empty?
    if arp.destroy
      puts "#{arp.ip}: last seen #{arp.updated_on} removed"
    else
      puts "#{arp.ip}: encountered trouble removing record"
    end
  end
end