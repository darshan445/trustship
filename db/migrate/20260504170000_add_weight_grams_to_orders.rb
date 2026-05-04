# frozen_string_literal: true

class AddWeightGramsToOrders < ActiveRecord::Migration[8.1]
  def change
    # weight in grams, default 500g (up to 500g tier)
    add_column :orders, :weight_grams, :integer, default: 500, null: false
  end
end
