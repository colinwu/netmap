class Jack < ActiveRecord::Base
  belongs_to :building
  belongs_to :port
  belongs_to :node
end
