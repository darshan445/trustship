# frozen_string_literal: true

class CreateShippingRates < ActiveRecord::Migration[8.1]
  def change
    create_table :shipping_rates, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.string :name, null: false
      t.string :payment_type, null: false
      t.integer :min_weight_grams, default: 0, null: false
      t.integer :max_weight_grams
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end

    add_index :shipping_rates, [ :payment_type, :min_weight_grams, :max_weight_grams ], unique: true, name: "index_shipping_rates_on_type_and_weight_range"
  end
end
