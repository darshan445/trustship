# frozen_string_literal: true

class AddCodAdvanceAndOrderAdvancePayments < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :cod_minimum_advance, :decimal, precision: 10, scale: 2, null: false, default: 0.0

    create_table :order_advance_payments, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid, index: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :razorpay_payment_link_id
      t.string :razorpay_payment_link_url
      t.string :razorpay_payment_id
      t.datetime :sent_at, null: false
      t.datetime :reminded_at
      t.datetime :paid_at
      t.datetime :seller_notified_at
      t.string :seller_decision, null: false, default: "pending"
      t.datetime :seller_decided_at
      t.timestamps
    end

    add_index :order_advance_payments, :order_id, unique: true
    add_index :order_advance_payments, :razorpay_payment_link_id, unique: true, where: "razorpay_payment_link_id IS NOT NULL"
    add_index :order_advance_payments, :paid_at
    add_index :order_advance_payments, :seller_decision
  end
end
