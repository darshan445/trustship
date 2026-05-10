class MakeSellerPhoneNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sellers, :phone, true
  end
end
