class CreateBuildings < ActiveRecord::Migration
  def self.up
    create_table :buildings do |t|
      t.column :long_name, :string
      t.column :short_name, :string
      t.column :bldg_number, :string
    end
  end

  def self.down
    drop_table :buildings
  end
end
