# frozen_string_literal: true

class OrderConfirmation < ApplicationRecord
  RESPONSES = %w[
    confirmed cancelled address_correction
  ].freeze

  SELLER_DECISIONS = %w[
    pending keep_waiting cancelled
  ].freeze

  POSITIVE_REPLIES = %w[
    yes yeah yep haan ha ok okay
    confirm confirmed correct right
    bilkul done proceed
  ].freeze

  NEGATIVE_REPLIES = %w[
    no nope nahi nahin cancel
    cancelled wrong stop
  ].freeze

  belongs_to :order

  validates :seller_decision, inclusion: { in: SELLER_DECISIONS }
  validates :response, inclusion: { in: RESPONSES }, allow_nil: true

  def self.classify_reply(message)
    normalized = message.to_s
                        .downcase
                        .strip
                        .gsub(/[^a-z0-9\s]/, "")
                        .split
                        .first(3)
                        .join(" ")

    if POSITIVE_REPLIES.any? { |r| normalized.include?(r) }
      "confirmed"
    elsif NEGATIVE_REPLIES.any? { |r| normalized.include?(r) }
      "cancelled"
    else
      "address_correction"
    end
  end

  def awaiting_response?
    responded_at.nil? && seller_decision == "pending"
  end

  def confirmed?
    response == "confirmed"
  end

  def cancelled?
    response == "cancelled" || seller_decision == "cancelled"
  end
end
