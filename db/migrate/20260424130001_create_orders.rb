# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :seller, null: false, foreign_key: true, type: :uuid
      t.references :buyer, null: false, foreign_key: true, type: :uuid
      t.text :raw_message
      t.string :product_name, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :address_line, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :pincode, null: false
      t.boolean :is_prepaid, null: false, default: false
      t.string :payment_reference
      t.string :aasm_state, null: false, default: "pending_verification"
      t.text :seller_note
      t.datetime :pincode_verified_at
      t.datetime :buyer_confirmed_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :rto_at
      t.datetime :undeliverable_at
      t.string :awb_number
      t.string :delhivery_shipment_id
      t.datetime :confirmation_sent_at
      t.datetime :confirmation_reminder_sent_at

      t.timestamps
    end

    add_index :orders, :aasm_state
    add_index :orders, :awb_number, unique: true
  end
end
