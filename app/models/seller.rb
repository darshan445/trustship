# frozen_string_literal: true

class Seller < ApplicationRecord
  PHONE_REGEX = /\A[6-9]\d{9}\z/

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  enum :status, { active: "active", inactive: "inactive" }, default: :active

  # early_access: platform fee waived during Early Access (default true for new sellers).
  # trial_ends_at: reserved for future time-limited access; nil means no end date for now.

  has_one_attached :seller_logo
  has_many :orders, inverse_of: :seller, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :business_name, presence: true
  validates :phone, presence: true,
            uniqueness: true,
            format: { with: PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }
  validates :shop_code, presence: true, uniqueness: true

  before_validation :normalize_phone
  before_validation :assign_shop_code, on: :create

  def email_required?
    false
  end

  def devise_will_save_change_to_email?
    false
  end

  def pickup_address_complete?
    pickup_address_line.present? &&
      pickup_city.present? &&
      pickup_state.present? &&
      pickup_pincode.present? &&
      delhivery_pickup_location_name.present?
  end

  def pickup_address_saved?
    pickup_address_line.present? &&
      pickup_city.present? &&
      pickup_state.present? &&
      pickup_pincode.present?
  end

  protected

  def send_devise_notification(notification, *args)
    if notification == :reset_password_instructions
      token = args.first
      if Rails.env.development? && token.present?
        opts = Rails.application.config.action_mailer.default_url_options || {}
        url = Rails.application.routes.url_helpers.edit_seller_password_url(
          reset_password_token: token,
          **opts
        )
        Rails.logger.info("[Seller] Password reset (dev): #{url}")
      else
        Rails.logger.info("[Seller] Password reset requested; add SMS or mail delivery for production.")
      end
      return
    end

    super
  end

  private

  def normalize_phone
    self.phone = phone.to_s.gsub(/\s+/, "") if phone.present?
  end

  def assign_shop_code
    return if shop_code.present?

    self.shop_code = generate_unique_shop_code
  end

  def generate_unique_shop_code
    loop do
      code = "SHOP#{SecureRandom.alphanumeric(4).upcase}"
      return code unless Seller.exists?(shop_code: code)
    end
  end
end
