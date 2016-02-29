class CreatePorts < ActiveRecord::Migration
  def self.up
    create_table :ports do |t|
      t.column :ifName, :string
      t.column :ifAlias, :string
      t.column :node_id, :integer
      t.column :building_id, :integer
      t.column :vlan, :integer
      t.column :label, :string
      t.column :comment, :string
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :ports
  end
end
