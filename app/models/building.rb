class Building < ActiveRecord::Base  
  has_many :ports
  has_many :nodes, :through => :ports
  validates_uniqueness_of :bldg_number, :long_name, :short_name
  validates_presence_of :bldg_number, :long_name, :short_name
end
