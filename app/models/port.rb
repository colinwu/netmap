class Port < ActiveRecord::Base
  belongs_to :node
  belongs_to :building
  has_many :links, :dependent => :destroy, :foreign_key => 'port_a_id'
  has_many :events, :dependent => :destroy

  def snmpget(var)
    n = self.node
    resp = n.snmpget("#{var}.#{self.ifIndex}")
    return resp
  end

  def snmpset(var, value)
    n = self.node
    resp = n.snmpset("#{var}.#{self.ifIndex}",value)
    return resp
  end

end
