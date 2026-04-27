# frozen_string_literal: true

class AddDelhiveryPickupLocationNameToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :delhivery_pickup_location_name, :string
  end
end
