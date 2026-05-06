# frozen_string_literal: true

class ShippingRate < ApplicationRecord
  PAYMENT_TYPES = %w[cod prepaid].freeze

  validates :name, :payment_type, presence: true
  validates :amount, presence: true
  validates :min_weight_grams, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :payment_type, inclusion: { in: PAYMENT_TYPES }

  scope :active, -> { where(is_active: true) }

  # +payment_type+ is "cod" or "prepaid". +weight_grams+ must fall within [min, max] (max nil = unlimited).
  def self.find_for_order(payment_type:, weight_grams:)
    w = weight_grams.to_i
    active.where(payment_type: payment_type.to_s)
      .where("min_weight_grams <= ?", w)
      .where("max_weight_grams IS NULL OR max_weight_grams >= ?", w)
      .order(min_weight_grams: :desc)
      .first
  end
end
