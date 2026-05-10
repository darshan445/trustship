# frozen_string_literal: true

class AddVerificationModeToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :verification_mode, :string, null: false, default: "whatsapp_automated"
    add_index :orders, :verification_mode
  end
end
