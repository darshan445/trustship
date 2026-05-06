# frozen_string_literal: true

class CreateProductsAndAddProductToOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.references :seller, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.integer :weight_grams
      t.string :sku
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end

    add_index :products, [ :seller_id, :name ]
    add_index :products, [ :seller_id, :is_active ]
    add_index :products, [ :seller_id, :sku ], unique: true, where: "sku IS NOT NULL"

    add_reference :orders, :product, foreign_key: true, type: :uuid
  end
end
