class DropIfAlias < ActiveRecord::Migration
  def self.up
    remove_column :ports, :ifAlias
  end

  def self.down
    add_column :ports, :ifAlias, :text
  end
end
