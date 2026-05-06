# frozen_string_literal: true

class AddGoogleAddressValidationToOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.datetime :address_validated_at
      t.string :address_confidence
      t.string :address_formatted
      t.decimal :address_latitude, precision: 10, scale: 6
      t.decimal :address_longitude, precision: 10, scale: 6
      t.string :address_validation_notes
    end
  end
end
