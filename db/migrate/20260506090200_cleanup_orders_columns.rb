# frozen_string_literal: true

class CleanupOrdersColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :orders, :address_line, :string
    remove_column :orders, :city, :string
    remove_column :orders, :state, :string
    remove_column :orders, :pincode, :string
    remove_column :orders, :pincode_verified_at, :datetime

    remove_column :orders, :awb_number, :string
    remove_column :orders, :delhivery_shipment_id, :string
    remove_column :orders, :shipped_at, :datetime
    remove_column :orders, :delivered_at, :datetime
    remove_column :orders, :rto_at, :datetime
    remove_column :orders, :undeliverable_at, :datetime
    remove_column :orders, :shipping_amount, :decimal, precision: 10, scale: 2
    remove_column :orders, :shipping_paid_at, :datetime
    remove_column :orders, :shipping_payment_id, :string
    remove_column :orders, :shipping_payment_link_id, :string
    remove_column :orders, :shipping_payment_link_url, :string
    remove_column :orders, :shipping_payment_status, :string

    remove_column :orders, :buyer_confirmed_at, :datetime
    remove_column :orders, :buyer_risk_assessed_at, :datetime
    remove_column :orders, :confirmation_sent_at, :datetime
    remove_column :orders, :confirmation_reminder_sent_at, :datetime
    remove_column :orders, :prepaid_incentive_sent_at, :datetime
    remove_column :orders, :payment_link_expires_at, :datetime
    remove_column :orders, :razorpay_payment_id, :string
    remove_column :orders, :razorpay_payment_link_id, :string
    remove_column :orders, :razorpay_payment_link_url, :string
  end
end
