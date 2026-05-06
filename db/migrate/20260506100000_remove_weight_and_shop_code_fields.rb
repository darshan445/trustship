# frozen_string_literal: true

class RemoveWeightAndShopCodeFields < ActiveRecord::Migration[8.1]
  def change
    remove_column :orders, :weight_grams, :integer
    remove_column :products, :weight_grams, :integer
    remove_column :sellers, :shop_code, :string
  end
end
