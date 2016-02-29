class CreateSysObjects < ActiveRecord::Migration
  def self.up
    create_table :sys_objects do |t|
      t.column :oid, :string
      t.column :name, :string
    end
  end

  def self.down
    drop_table :sys_objects
  end
end
