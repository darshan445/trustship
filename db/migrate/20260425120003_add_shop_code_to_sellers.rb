# frozen_string_literal: true

class AddShopCodeToSellers < ActiveRecord::Migration[8.1]
  def up
    add_column :sellers, :shop_code, :string

    Seller.reset_column_information
    Seller.find_each do |seller|
      seller.update_column(:shop_code, generate_unique_shop_code_for(Seller))
    end

    change_column_null :sellers, :shop_code, false
    add_index :sellers, :shop_code, unique: true
  end

  def down
    remove_index :sellers, :shop_code, if_exists: true
    remove_column :sellers, :shop_code
  end

  private

  def generate_unique_shop_code_for(model_class)
    loop do
      code = "SHOP#{SecureRandom.alphanumeric(4).upcase}"
      return code unless model_class.exists?(shop_code: code)
    end
  end
end
