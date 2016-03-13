class AddIfIndexToArpcaches < ActiveRecord::Migration
  def change
    add_column :arpcaches, :ifIndex, :integer
  end
end
