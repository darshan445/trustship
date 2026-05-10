class AddEmailToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :email, :string
    add_index :sellers, :email, unique: true
  end
end
