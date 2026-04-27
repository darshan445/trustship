# frozen_string_literal: true

class Buyer < ApplicationRecord
  PHONE_REGEX = /\A[6-9]\d{9}\z/

  enum :risk_level, { low: "low", medium: "medium", high: "high" }, default: :low

  has_many :orders, inverse_of: :buyer, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :phone, presence: true,
            uniqueness: true,
            format: { with: PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }

  before_validation :normalize_phone

  def repeat_buyer?
    rto_count.positive? || successful_delivery_count.positive?
  end

  def high_risk?
    risk_level == "high"
  end

  def increment_rto_count!
    increment!(:rto_count)
    Buyers::CalculateRiskScore.execute(buyer_id: id)
    reload
  end

  def increment_successful_delivery_count!
    increment!(:successful_delivery_count)
    Buyers::CalculateRiskScore.execute(buyer_id: id)
    reload
  end

  private

  def normalize_phone
    return if phone.blank?

    digits = phone.to_s.gsub(/\s+/, "").delete_prefix("+").gsub(/\D/, "")
    digits =
      if digits.length == 12 && digits.start_with?("91")
        digits[2, 10]
      elsif digits.length == 11 && digits.start_with?("0")
        digits[1, 10]
      elsif digits.length > 10
        digits[-10, 10]
      else
        digits
      end
    self.phone = digits
  end
end
