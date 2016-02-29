class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :whoEnabled
      t.string :whoDisabled
      t.datetime :whenEnabled
      t.datetime :whenDisabled
      t.integer :port_id

      t.timestamps null: false
    end
  end
end
