# frozen_string_literal: true

class OrderAdvancePayment < ApplicationRecord
  SELLER_DECISIONS = %w[
    pending keep_waiting cancelled
  ].freeze

  belongs_to :order

  validates :amount, numericality: { greater_than: 0 }
  validates :seller_decision, inclusion: { in: SELLER_DECISIONS }

  def paid?
    paid_at.present?
  end

  def awaiting_payment?
    paid_at.nil? && seller_decision == "pending"
  end

  def reminded?
    reminded_at.present?
  end
end
