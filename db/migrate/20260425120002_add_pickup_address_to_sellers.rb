# frozen_string_literal: true

class AddPickupAddressToSellers < ActiveRecord::Migration[8.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.string :pickup_address_line
      t.string :pickup_city
      t.string :pickup_state
      t.string :pickup_pincode
      t.string :pickup_name
      t.string :pickup_phone
    end
  end
end
