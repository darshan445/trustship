# frozen_string_literal: true

class AddShippingPaymentFieldsToOrders < ActiveRecord::Migration[8.1]
  def up
    change_table :orders, bulk: true do |t|
      t.decimal :shipping_amount, precision: 10, scale: 2
      t.string :shipping_payment_status, default: "pending", null: false
      t.string :shipping_payment_link_id
      t.string :shipping_payment_link_url
      t.string :shipping_payment_id
      t.datetime :shipping_paid_at
    end

    add_index :orders, :shipping_payment_link_id, unique: true, where: "shipping_payment_link_id IS NOT NULL"

  end

  def down
    remove_index :orders, name: "index_orders_on_shipping_payment_link_id"
    change_table :orders, bulk: true do |t|
      t.remove :shipping_amount, :shipping_payment_status, :shipping_payment_link_id,
               :shipping_payment_link_url, :shipping_payment_id, :shipping_paid_at
    end
  end
end
