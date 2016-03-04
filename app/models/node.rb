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
    module_list = SNMP::MIB.list_imported
    manager = SNMP::Manager.new(:host => self.ip, :community => pw, :mib_modules => $module_list)
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
    manager = SNMP::Manager.new(:host => self.ip, :community => pw, :mib_modules => $module_list)
    snmp_val= manager.get_value(var).class.new(value)
    begin
      v = SNMP::VarBind.new($mib.oid(var),snmp_val)
      resp = manager.set(v)
      return true
    rescue
      $snmpError = SNMP::PDU.new(resp.request_id, resp.varbind_list, resp.error_status).error_status.to_s
      return nil
    end
  end

  def vlans( pw = self.commStr )
    list = Hash.new
    if pw != '**UNKNOWN**'
      self.snmpwalk('vtpVlanName').each do |oid,name|
        oid =~ /\.(\d+)$/
        vlan = $1
        unless vlan == 1 or vlan == 1002 or vlan == 1003 or vlan == 1004 or vlan == 1005
          list[vlan] = name
        end
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

end
