class AddIfindex < ActiveRecord::Migration
  def self.up
    add_column :ports, :ifIndex, :integer
  end

  def self.down
    remove_column :ports, :ifIndex
  end
end
