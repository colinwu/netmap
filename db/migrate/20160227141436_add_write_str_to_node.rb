class AddWriteStrToNode < ActiveRecord::Migration
  def change
    add_column :nodes, :writeStr, :string
  end
end
