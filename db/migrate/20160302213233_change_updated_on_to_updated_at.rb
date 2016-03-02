class ChangeUpdatedOnToUpdatedAt < ActiveRecord::Migration
  def change
    rename_column :arpcaches, :updated_on, :updated_at
    rename_column :links, :updated_on, :updated_at
    rename_column :nodes, :updated_on, :updated_at
    rename_column :ports, :updated_on, :updated_at
    add_column :arpcaches, :created_at, :datetime
    add_column :nodes, :created_at, :datetime
    add_column :ports, :created_at, :datetime
    add_column :links, :created_at, :datetime
  end
end
