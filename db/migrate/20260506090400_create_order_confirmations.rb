# frozen_string_literal: true

class CreateOrderConfirmations < ActiveRecord::Migration[8.1]
  def change
    create_table :order_confirmations, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.datetime :sent_at, null: false
      t.datetime :reminded_at
      t.datetime :responded_at
      t.string :response
      t.text :corrected_address
      t.datetime :seller_notified_at
      t.string :seller_decision, null: false, default: "pending"
      t.datetime :seller_decided_at
      t.timestamps
    end

    add_index :order_confirmations, :sent_at
    add_index :order_confirmations, :response
    add_index :order_confirmations, :seller_decision
  end
end
