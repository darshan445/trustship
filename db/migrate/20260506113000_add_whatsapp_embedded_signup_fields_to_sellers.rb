# frozen_string_literal: true

class AddWhatsappEmbeddedSignupFieldsToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :whatsapp_onboarding_status, :string, null: false, default: "not_connected"
    add_column :sellers, :whatsapp_waba_id, :string
    add_column :sellers, :whatsapp_phone_number_id, :string
    add_column :sellers, :whatsapp_display_phone_number, :string
    add_column :sellers, :whatsapp_verified_name, :string
    add_column :sellers, :whatsapp_linked_at, :datetime

    add_index :sellers, :whatsapp_phone_number_id, unique: true, where: "whatsapp_phone_number_id IS NOT NULL"
    add_index :sellers, :whatsapp_waba_id
    add_index :sellers, :whatsapp_onboarding_status
  end
end
