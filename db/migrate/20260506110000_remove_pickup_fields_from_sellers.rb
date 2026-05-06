# frozen_string_literal: true

class RemovePickupFieldsFromSellers < ActiveRecord::Migration[8.1]
  def change
    remove_column :sellers, :pickup_address_line, :string
    remove_column :sellers, :pickup_city, :string
    remove_column :sellers, :pickup_state, :string
    remove_column :sellers, :pickup_pincode, :string
    remove_column :sellers, :pickup_name, :string
    remove_column :sellers, :pickup_phone, :string
  end
end
