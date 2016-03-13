class Node < ActiveRecord::Base
  #  has_many :ports, :dependent => :destroy
  has_many :ports

  validates_uniqueness_of :sysName
  validates_uniqueness_of :ip
  validates_format_of :ip, :with => /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/, :message => "does not appear to be a valid IP address."

  # It will be necessary to use a different community string to access some of the oid's
  # in the BRIDGE mib. They will be of the form pw@vlan
  # Returns either a Hash object that has only one element, or nil
  def snmpget(var, pw = self.commStr)
    $snmpError = String.new
    manager = SNMP::Manager.new(:host => self.ip, :community => pw, :timeout => 10, :mib_modules => $module_list)
    begin
      resp = manager.get(var)
      resp.each_varbind do |vb|
        return (vb.value)
      end
    rescue
      return nil
    end
  end

  def snmpwalk(var, pw = self.commStr)
    return_val = Hash.new
    manager = SNMP::Manager.new(:host => self.ip, :community => pw, :timeout => 10, :mib_modules => $module_list)
    begin
      manager.walk(var) do |row|
        row.each do |vb|
          return_val[vb.name.to_s] = vb.value
        end
      end
      return return_val
    rescue
      return nil
    end
  end

  def snmpset(var, value, pw = self.writeStr)
    $snmpError = String.new
    unless pw.nil? or pw.empty?
      manager = SNMP::Manager.new(:host => self.ip, :community => pw, :timeout => 10, :mib_modules => $module_list)
      snmp_val= manager.get_value(var).class.new(value)
      begin
        v = SNMP::VarBind.new($mib.oid(var),snmp_val)
        resp = manager.set(v)
        return true
      rescue
        $snmpError = SNMP::PDU.new(resp.request_id, resp.varbind_list, resp.error_status).error_status.to_s
        return nil
      end
    else
      $snmpError = "No write string."
      flash[:error] = "No write string configured for #{self.sysName}"
      $log.info("No write string configured for #{self.sysName}")
      return nil
    end
  end

  def vlans( pw = self.commStr )
    list = Hash.new
    if pw != '**UNKNOWN**'
      self.snmpwalk('CISCO-VTP-MIB::vtpVlanName').each do |oid,name|
        oid =~ /\.(\d+)$/
        vlan = $1
#         unless vlan == 1 or vlan == 1002 or vlan == 1003 or vlan == 1004 or vlan == 1005
          list[vlan] = name
#         end
      end
      return list
    else
      return nil
    end
  end

  # Given a node id retrieve its ifName <-> ifIndex mapping. If the retrieved
  # interface doesn't already exist create it. If it already exists set it's
  # ifIndex value to the retrieved value.

  def get_ifindex
    base_oid = $mib.oid('IF-MIB::ifName').to_s
    ifnames = self.snmpwalk('IF-MIB::ifName')
    unless ifnames.nil? or ifnames.empty?
      ifnames.each do |key,val|
        ifIndex = /ifName\.(.+)/.match(key)[1]
        p = self.ports.find_by_ifName val.to_s
        if p.nil?
          Port.create(:node_id => self.id, :ifName => val, :ifIndex => ifIndex)
        else
          p.update_attributes(:ifIndex => ifIndex)
        end
      end
    end
  end

  def get_platform
    obj = self.snmpget('1.3.6.1.2.1.47.1.1.1.1.13.1001')
    if obj.nil? or obj.blank? or obj.to_s == 'noSuchInstance'
      obj = self.snmpget('1.3.6.1.2.1.47.1.1.1.1.13.1')
      if obj.nil? or obj.blank? or obj.to_s == 'noSuchInstance'
        self.platform = 'unknown'
      else
        self.platform = obj.to_s
      end
    else
      self.platform = obj.to_s
    end
  end

  # 
  def get_routes
    routes = []
    if (self.capability & 1) == 1
      routeTypeArr = self.snmpwalk('RFC1213-MIB::ipRouteType')
      routeMaskArr = self.snmpwalk('RFC1213-MIB::ipRouteMask')
      routeIfIndexArr = self.snmpwalk('RFC1213-MIB::ipRouteIfIndex')
      
      # only keep local routes
      routeTypeArr.each do |key,val|
        key =~ /ipRouteType.([\d.]+)/
        net = $1
        routes.push({:net => $1, :mask => routeMaskArr["RFC1213-MIB::ipRouteMask.#{net}"].to_s, :type => val.to_i, :ifIndex => routeIfIndexArr["RFC1213-MIB::ipRouteIfIndex.#{net}"].to_i})
      end
    end
    return routes
  end
  
  def get_arp
    arp = []
    if (self.capability & 1) == 1
      arplist = self.snmpwalk("ipNetToMediaPhysAddress")
      arplist.each do |key,val|
        m = /\.(\d+)\.(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/.match(key)
        if not m.nil?
          arp.push({:ifIndex => m[1], :ip => m[2], :mac => val.to_s.unpack("H2H2H2H2H2H2").join('')})
        end
      end
    end
    return arp
  end
  
  def findPhysInt( target )
    physIfIndex = nil
    ifIndex = nil
    # find the physical interface this net is attached to
    dec_mac_str = target[:mac_str].unpack('a2a2a2a2a2a2').collect{|i| i.hex}.join('.')
    ifType = self.snmpget("IF-MIB::ifType.#{target[:ifIndex]}").to_i
    if ifType == 53
      vlanStr = self.snmpget("IF-MIB::ifName.#{target[:ifIndex]}").to_s
      if vlanStr =~ /^v[^0-9]*(\d+)$/i
        vlan = $1
        vlanpw = self.commStr + '@' + vlan.to_s
      end
      fdPort = self.snmpget("dot1dTpFdbPort.#{dec_mac_str}",vlanpw)
      $log.debug("fdPort = #{fdPort}")
      unless fdPort.to_s == 'noSuchInstance'
        port = self.snmpget("dot1dBasePortIfIndex.#{fdPort}",vlanpw).to_i
        ifType = self.snmpget("IF-MIB::ifType.#{port}",vlanpw).to_i
        if ifType == 53
          self.snmpwalk("pagpGroupIfIndex",vlanpw).each do |k,v|
            if v.to_i == port
              k =~ /\.(\d+)$/
              physIfIndex = $1
              vlanStr = self.snmpget("IF-MIB::ifName.#{physIfIndex}", vlanpw).to_s
              if vlanStr == /^v[^0-9]*(\d+)$/i
                vlan = $1
              end
              break
            end
          end
        else
          physIfIndex = port
        end
        return([physIfIndex, vlan])
      else
        return [nil,nil]
      end
    end
    
  end
  
  def findNeighbour(ifIndex)
    link = self.ports.where('ifIndex = ?', ifIndex).first.links.first
    unless link.nil?
      node = link.port_b.node
    else
      node = nil
    end
    return node
  end
  
  def findCAM( target )
    dec_mac_str = target[:mac_str].unpack('a2a2a2a2a2a2').collect{|i| i.hex}.join('.')
    vlanpw = self.commStr + '@' + target[:vlan].to_s
    ifIndex = nil
    tmp = self.snmpget("dot1dTpFdbPort.#{dec_mac_str}", vlanpw)
    unless tmp.nil?
      ifIndex = self.snmpget("dot1dBasePortIfIndex.#{tmp}", vlanpw).to_i
      ifType = self.snmpget("IF-MIB::ifType.#{ifIndex}").to_i
      if ifType == 53
        self.snmpwalk("pagpGroupIfIndex").each do |k,v|
          if v.to_i == ifIndex
            k =~ /\.(\d+)$/;
            ifIndex = $1
            break
          end
        end
      end
    end
    return (ifIndex.nil? ? ifIndex : self.ports.where(["ifIndex = ?", ifIndex]).first)
  end
end
