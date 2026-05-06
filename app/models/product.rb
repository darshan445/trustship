# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :seller
  has_many :orders, inverse_of: :product, dependent: :nullify

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cod_minimum_advance, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: { scope: :seller_id }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :for_seller, ->(seller) { where(seller: seller) }
end
