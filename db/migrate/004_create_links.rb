class CreateLinks < ActiveRecord::Migration
  def self.up
    create_table :links do |t|
      t.column :port_a_id, :integer
      t.column :port_b_id, :integer
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :links
  end
end
