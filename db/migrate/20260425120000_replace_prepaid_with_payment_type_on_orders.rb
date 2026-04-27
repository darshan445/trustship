# frozen_string_literal: true

class ReplacePrepaidWithPaymentTypeOnOrders < ActiveRecord::Migration[8.1]
  def change
    remove_column :orders, :is_prepaid, :boolean
    remove_column :orders, :payment_reference, :string

    add_column :orders, :payment_type, :string, null: false, default: "full_cod"
    add_column :orders, :advance_amount, :decimal, precision: 10, scale: 2
    add_column :orders, :razorpay_payment_link_id, :string
    add_column :orders, :razorpay_payment_link_url, :string
    add_column :orders, :razorpay_payment_id, :string
    add_column :orders, :payment_link_expires_at, :datetime
    add_column :orders, :prepaid_incentive_sent_at, :datetime

    add_index :orders, :razorpay_payment_link_id, unique: true, where: "razorpay_payment_link_id IS NOT NULL"
  end
end
