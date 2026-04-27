# frozen_string_literal: true

class CreateBuyers < ActiveRecord::Migration[8.1]
  def change
    create_table :buyers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.integer :rto_count, null: false, default: 0
      t.integer :successful_delivery_count, null: false, default: 0
      t.string :risk_level, null: false, default: "low"

      t.timestamps
    end

    add_index :buyers, :phone, unique: true
  end
end
