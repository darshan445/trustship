# frozen_string_literal: true

class AddBuyerRiskAssessedAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :buyer_risk_assessed_at, :datetime
  end
end
