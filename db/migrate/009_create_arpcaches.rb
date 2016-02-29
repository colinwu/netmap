class CreateArpcaches < ActiveRecord::Migration
  def self.up
    create_table :arpcaches do |t|
      t.column :ip, :string, :null => false, :default => '-'
      t.column :mac, :string, :null => false, :default => '-'
      t.column :router, :string, :null => false, :default => '-'
      t.column :if, :string, :null => false, :default => '-'
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :arpcaches
  end
end
