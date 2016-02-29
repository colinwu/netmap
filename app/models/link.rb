class Link < ActiveRecord::Base
  belongs_to :port_a, :class_name => "Port", :foreign_key => 'port_a_id'
  belongs_to :port_b, :class_name => "Port", :foreign_key => 'port_b_id'
end
