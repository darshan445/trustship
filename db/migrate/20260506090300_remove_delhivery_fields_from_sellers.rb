# frozen_string_literal: true

class RemoveDelhiveryFieldsFromSellers < ActiveRecord::Migration[8.1]
  def change
    remove_column :sellers, :delhivery_pickup_location_name, :string
  end
end
