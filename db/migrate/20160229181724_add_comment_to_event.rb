class AddCommentToEvent < ActiveRecord::Migration
  def change
    add_column :events, :comment, :string
  end
end
