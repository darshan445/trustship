# frozen_string_literal: true

class OrderForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :buyer_name, :string
  attribute :buyer_phone, :string
  attribute :product_name, :string
  attribute :product_id, :string
  attribute :amount, :decimal
  attribute :raw_address, :string
  attribute :raw_message, :string
  attribute :seller_note, :string
  attribute :payment_type, :string, default: "full_cod"

  validates :buyer_name, :buyer_phone, :product_name, :raw_address,
            presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :buyer_phone, format: { with: Buyer::PHONE_REGEX, message: "must be a valid 10-digit Indian mobile number" }
  validates :payment_type, inclusion: { in: %w[full_cod full_prepaid], message: "must be COD or prepaid" }

  def self.model_name
    ActiveModel::Name.new(self, nil, "Order")
  end
end
