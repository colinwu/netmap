class CreateNodes < ActiveRecord::Migration
  def self.up
    create_table :nodes do |t|
      t.column :sysName, :string
      t.column :ip, :string
      t.column :commStr, :string
      t.column :platform, :string
      t.column :capability, :integer
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :nodes
  end
end
