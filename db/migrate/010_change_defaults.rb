class ChangeDefaults < ActiveRecord::Migration
  def self.up
    change_column :nodes, :sysName,    :string, :null => false, :default => '-'
    change_column :nodes, :ip,         :string, :null => false, :default => '-'
    change_column :nodes, :commStr,    :string, :null => false, :default => '**UNKNOWN**'
    change_column :nodes, :platform,   :string, :null => false, :default => '-'
    change_column :nodes, :capability, :integer, :null => false, :default => 0

    change_column :ports, :ifName, :string, :null => false, :default => '-'
    change_column :ports, :vlan,   :integer, :null => false, :default => 0
    change_column :ports, :label,  :string, :null => false, :default => '-'
    change_column :ports, :comment,:string, :null => false, :default => '-'

  end

  def self.down
  end
end
