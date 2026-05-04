# frozen_string_literal: true

class AddTermsAcceptanceToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :terms_accepted, :boolean, default: false, null: false
    add_column :sellers, :terms_accepted_at, :datetime
  end
end
