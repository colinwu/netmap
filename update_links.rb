require 'snmp'
::ApplicationController
$log.info("update_links started.")

Node.where('commStr <> "**UNKNOWN**"').each do |devA|
  $log.debug("devA = #{devA.ip}")
  remoteIP = Hash.new
  remotePort = Hash.new
  localPort = Hash.new
  remoteCap = Hash.new
  idList = Array.new
  pwlist = ['fhsr22439', 'public', '**UNKNOWN**']
  
  # Retrieve neighbours' IP addresses
  response = devA.snmpwalk('cdpCacheAddress')
  if response.nil?
    $log.warn("No result from #{devA.sysName} for 'cdpCacheAddress'")
    next
  else
    response.each do |key,val|
      /cdpCacheAddress\.(.+)/.match(key)
      id = $1
      ip = SNMP::IpAddress.new(val.to_s)
      remoteIP[id] = ip.to_s
    end
  end

  # Retrieve the name of neighbours' interfaces facing us
  response = devA.snmpwalk('cdpCacheDevicePort')
  if response.nil?
    $log.warn("No result from #{devA.sysName} for 'cdpCacheDevicePort'")
  else
    response.each do |key,val|
      /cdpCacheDevicePort\.(.+)/.match(key)
      id= $1
      if val =~ /^FastEthernet/
        val.sub!(/stEthernet/,'')
      elsif val =~ /^GigabitEthernet/
        val.sub!(/gabitEthernet/,'')
      else
        val.to_s
      end
      remotePort[id] = val
      # Retrieve the corresponding local interface's ifName
      /^(\d+)\./.match(id)
      ifIndex = $1
      tmp = devA.snmpget($mib.oid('ifName').to_s+".#{ifIndex}")
      localPort[id] = tmp.to_s
    end
  end

  # for each neighbour
  remoteIP.each_pair do |id,ip|
    # See if it exists in the database
    devB = Node.find_by_ip ip
    if devB.nil?
      $log.info("Remote device (#{ip}) not in database.")
      # neighbour doesn't exist. Get its sysName & platform string
      resp = devA.snmpget("cdpCacheDeviceId.#{id}")
      if resp.to_s =~ /\((.+)\)/
        # The remote ID is of the form 'XXXXX(HOSTNAME)'
        r_sysName = $1
      elsif resp.to_s =~ /^([^.]+)/
        # just a text string (not an IP address)
        r_sysName = $1
      end
      # Now check if a record with the sysName exists
      devB = Node.find_by_sysName r_sysName
      if devB.nil?
        resp = devA.snmpget("cdpCachePlatform.#{id}")
        devB = Node.create(:sysName => r_sysName, :ip => ip, :platform => resp.to_s)
        # remote device capabilities
        resp = devA.snmpget("cdpCacheCapabilities.#{id}")
        # Only the least significant 8 bits are used in the Capabilities field
        devB.capability = resp.unpack("c#{resp.length}")[3].to_s
        # See if the community string is one of the known ones
        pwlist.each do |pw|
          devB.commStr = pw
          break if pw == '**UNKNOWN**'
          resp = devB.snmpget('RFC1213-MIB::sysName').to_s #sysName
          break unless resp.nil? or resp.empty?
        end
        devB.save
        if devB.commStr != '**UNKNOWN**'
          devB.get_ifindex
        end
        $log.info("Remote device #{devB.sysName} has been added to the database.")
      else
        resp = devA.snmpget("cdpCacheCapabilities.#{id}")
        # Only the least significant 8 bits are used in the Capabilities field
        devB.capability = resp.unpack("c#{resp.length}")[3]
        devB.save
      end
    end

    # See if the port is already in the database
    portB = Port.where("node_id = '#{devB.id}' and ifName = '#{remotePort[id]}'").first
    if portB.nil?
      portB = Port.create(:ifName => remotePort[id], :node_id => devB.id)
      $log.info("Remote port #{devB.sysName} #{remotePort[id]} has been added to the database.")
    end
    portB.comment = "link to #{devA.sysName}"
    portB.label = '-'
    portB.save

    #create the link record if it doesn't exist already
    portA = Port.where("node_id = '#{devA.id}' and ifName = '#{localPort[id]}'").first
    if portA.nil?
      portA = Port.create(:ifName => localPort[id], :node_id => devA.id)
      $log.info("Local port #{devA.sysName} #{portA.ifName} has been added to the database.")
    end
    portA.comment = "link to #{devB.sysName}"
    portA.label = '-'
    portA.save

    link = Link.where("port_a_id = '#{portA.id}' and port_b_id = '#{portB.id}'").first
    if link.nil?
      Link.create(:port_a_id => portA.id, :port_b_id => portB.id)
      $log.info("#{devA.sysName}:#{portA.ifName} to #{devB.sysName}:#{portB.ifName} link created.")
    end
    link = Link.where("port_a_id = '#{portB.id}' and port_b_id = '#{portA.id}'").first
    if link.nil?
      Link.create(:port_a_id => portB.id, :port_b_id => portA.id)
      $log.info("#{devB.sysName}:#{portB.ifName} to #{devA.sysName}:#{portA.ifName} back link created.")
    end
  end

end
