# frozen_string_literal: true

class AddEarlyAccessAndTrialEndsAtToSellers < ActiveRecord::Migration[8.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.boolean :early_access, default: true, null: false
      t.datetime :trial_ends_at
    end
  end
end
