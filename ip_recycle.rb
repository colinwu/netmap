#
# Program to generate a list of candidate addresses within a specified /24
# that can be recycled. This is done by searching for IP addresses that
# have not been seen on the network for a certain amount of time (the default
# is 1 year).
#
# Must account for the special case of addresses that have DNS records but
# not in the ARP cache.
#

require 'resolv'

while ARGV.length >= 1
  net = ARGV.shift

  (1..254).each do |host|
    hostnames = Array.new()
    ip = "#{net}.#{host}"
    begin
      h = Resolv.getname(ip)
    rescue
#      puts "Resolver error: #{$!}"
    end
    if not h.nil?
      hostnames << h
      recent = Arpcache.find :first, :conditions => "updated_on > date_sub(now(), INTERVAL 1 YEAR) and ip = '#{ip}'"
      if recent.nil? #not been seen in the past year
        candidate = Arpcache.find :first, :conditions => "updated_on < date_sub(now(), INTERVAL 1 YEAR) and ip = '#{ip}'", :order => 'updated_on'
        if candidate.nil?  # not in arpcache table
          print ip,"|\tN/A|\t",hostnames[0],"|\tNever seen\n"
        else
          print ip,"|\t",candidate.mac,"|\t",hostnames[0],"|\t",candidate.updated_on,"\n"
        end
      end
    end
  end
end
