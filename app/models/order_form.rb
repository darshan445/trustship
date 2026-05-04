# frozen_string_literal: true

class OrderForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :buyer_name, :string
  attribute :buyer_phone, :string
  attribute :product_name, :string
  attribute :amount, :decimal
  attribute :address_line, :string
  attribute :city, :string
  attribute :state, :string
  attribute :pincode, :string
  attribute :raw_message, :string
  attribute :seller_note, :string
  attribute :payment_type, :string, default: "full_cod"
  attribute :weight_grams, :integer, default: 500

  validates :buyer_name, :buyer_phone, :product_name, :address_line, :city, :state, :pincode,
            presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :buyer_phone, format: { with: Buyer::PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }
  validates :pincode, format: { with: /\A\d{6}\z/, message: "must be 6 digits" }
  validates :payment_type, inclusion: { in: %w[full_cod full_prepaid], message: "must be COD or prepaid" }
  validates :weight_grams, inclusion: { in: Order::WEIGHT_TIERS.keys, message: "must select a valid weight tier" }

  def self.model_name
    ActiveModel::Name.new(self, nil, "Order")
  end
end
