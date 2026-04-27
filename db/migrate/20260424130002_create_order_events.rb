# frozen_string_literal: true

class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.string :from_state
      t.string :to_state, null: false
      t.string :event_name, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :triggered_by, null: false

      t.timestamps
    end
  end
end
