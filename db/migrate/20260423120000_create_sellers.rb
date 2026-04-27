# frozen_string_literal: true

class CreateSellers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :sellers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :business_name, null: false
      t.string :status, null: false, default: "active"
      t.string :encrypted_password, null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.timestamps
    end

    add_index :sellers, :phone, unique: true
    add_index :sellers, :reset_password_token, unique: true
  end
end
