# frozen_string_literal: true

class Seller < ApplicationRecord
  PHONE_REGEX = /\A[6-9]\d{9}\z/

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  enum :status, { active: "active", inactive: "inactive" }, default: :active
  enum :whatsapp_onboarding_status, {
    not_connected: "not_connected",
    pending: "pending",
    connected: "connected",
    failed: "failed"
  }, default: :not_connected

  # early_access: platform fee waived during Early Access (default true for new sellers).
  # trial_ends_at: reserved for future time-limited access; nil means no end date for now.

  has_one_attached :seller_logo
  has_many :orders, inverse_of: :seller, dependent: :restrict_with_exception
  has_many :products, inverse_of: :seller, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :business_name, presence: true
  validates :phone, uniqueness: true, allow_nil: true,
            format: { with: PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number", allow_nil: true }
  validates :whatsapp_phone_number_id, uniqueness: true, allow_nil: true

  before_validation :normalize_phone, if: -> { phone.present? }

  def whatsapp_connected?
    connected? && whatsapp_phone_number_id.present?
  end

  private

  def normalize_phone
    self.phone = phone.to_s.gsub(/\s+/, "") if phone.present?
  end
end
