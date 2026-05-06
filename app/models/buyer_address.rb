# frozen_string_literal: true

class BuyerAddress < ApplicationRecord
  CONFIDENCE_LEVELS = %w[
    high medium low failed pending unknown
  ].freeze

  belongs_to :buyer
  has_many :orders, inverse_of: :buyer_address, dependent: :nullify

  validates :raw_address, presence: true
  validates :address_confidence, inclusion: { in: CONFIDENCE_LEVELS }, allow_nil: true

  scope :validated, -> { where.not(validated_at: nil) }
  scope :high_confidence, -> { where(address_confidence: "high") }
  scope :reusable, -> { where(address_confidence: %w[high medium]).where.not(validated_at: nil) }

  def reusable?
    validated_at.present? && %w[high medium].include?(address_confidence)
  end

  def confidence_label
    case address_confidence
    when "high" then "Address Verified"
    when "medium" then "Address Approximate"
    when "low" then "Address Unclear"
    when "failed" then "Address Not Found"
    when "pending" then "Validation Pending"
    else "Unknown"
    end
  end
end
