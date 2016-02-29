data = open('Cisco-Products','r')
data.each do |line|
  line.chomp!
  stuff = line.split
  s = SysObject.create(:oid => stuff[1], :name => stuff[0])
end
