# frozen_string_literal: true

class OrderEvent < ApplicationRecord
  TRIGGERED_BY_VALUES = %w[system seller buyer].freeze

  belongs_to :order, inverse_of: :order_events

  validates :to_state, presence: true
  validates :event_name, presence: true
  validates :triggered_by, presence: true, inclusion: { in: TRIGGERED_BY_VALUES }
end
