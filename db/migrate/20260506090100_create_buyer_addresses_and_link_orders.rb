# frozen_string_literal: true

class CreateBuyerAddressesAndLinkOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :buyer_addresses, id: :uuid do |t|
      t.references :buyer, null: false, foreign_key: true, type: :uuid
      t.text :raw_address, null: false
      t.string :address_formatted
      t.string :address_confidence
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.boolean :is_primary, default: false
      t.datetime :validated_at
      t.timestamps
    end

    add_index :buyer_addresses, :address_confidence
    add_index :buyer_addresses, [:buyer_id, :is_primary]

    add_reference :orders, :buyer_address, foreign_key: true, type: :uuid

    remove_column :orders, :address_validated_at, :datetime
    remove_column :orders, :address_confidence, :string
    remove_column :orders, :address_formatted, :string
    remove_column :orders, :address_latitude, :decimal, precision: 10, scale: 6
    remove_column :orders, :address_longitude, :decimal, precision: 10, scale: 6
    remove_column :orders, :address_validation_notes, :string
  end
end
