# frozen_string_literal: true

class Order < ApplicationRecord
  include AASM

  STATUS_FILTER_MAP = {
    "pending" => "pending_verification",
    "high_risk" => "high_risk",
    "confirmed" => "confirmed",
    "green_zone" => "green_zone",
    "shipped" => "shipped",
    "delivered" => "delivered",
    "rto" => "rto"
  }.freeze

  # Tier ceiling (grams) => rates (₹). COD and UPI payment — single source of truth for seller-facing pricing.
  WEIGHT_TIERS = {
    500 => { cod: 149, prepaid: 119 },
    1000 => { cod: 199, prepaid: 169 },
    2000 => { cod: 249, prepaid: 219 },
    5000 => { cod: 329, prepaid: 299 }
  }.freeze

  attr_accessor :pending_event_triggered_by, :pending_event_metadata

  belongs_to :seller
  belongs_to :buyer
  has_one_attached :shipping_label
  has_many :order_events, inverse_of: :order, dependent: :restrict_with_exception

  enum :payment_type, {
    full_prepaid: "full_prepaid",
    partial_cod: "partial_cod",
    full_cod: "full_cod"
  }, default: :full_cod

  validates :product_name, presence: true
  validates :amount, presence: true
  validates :address_line, :city, :state, :pincode, presence: true
  validates :weight_grams, inclusion: { in: WEIGHT_TIERS.keys }

  def shipping_rate
    pt = full_prepaid? ? "prepaid" : "cod"
    row = ShippingRate.find_for_order(payment_type: pt, weight_grams: weight_grams)
    return row.amount if row.present?

    tier = current_tier_rates
    full_prepaid? ? tier[:prepaid] : tier[:cod]
  end

  def base_shipping_rate
    current_tier_rates[:cod]
  end

  def prepaid_discount
    tier = current_tier_rates
    tier[:cod] - tier[:prepaid]
  end

  def shipping_payment_paid?
    shipping_payment_status == "paid"
  end

  def weight_tier_label
    case weight_grams
    when 0..500 then "Upto 500g"
    when 501..1000 then "500g - 1kg"
    when 1001..2000 then "1kg - 2kg"
    else "2kg - 5kg"
    end
  end

  aasm column: :aasm_state, create_scopes: false do
    state :pending_verification, initial: true
    state :undeliverable
    state :high_risk
    state :address_mismatch
    state :confirmed
    state :green_zone
    state :shipped
    state :delivered
    state :rto
    state :cancelled

    after_all_transitions :log_order_event

    event :mark_undeliverable do
      transitions from: :pending_verification, to: :undeliverable,
                  after: :set_undeliverable_at
    end

    event :mark_high_risk do
      transitions from: :pending_verification, to: :high_risk
    end

    event :confirm do
      transitions from: [ :pending_verification, :high_risk ], to: :confirmed,
                  after: :set_buyer_confirmed_at
    end

    event :mark_address_mismatch do
      transitions from: :pending_verification, to: :address_mismatch
    end

    event :enter_green_zone do
      transitions from: :confirmed, to: :green_zone
    end

    event :ship do
      transitions from: :green_zone, to: :shipped,
                  guard: :awb_number_present?,
                  after: :set_shipped_at
    end

    event :mark_delivered do
      transitions from: :shipped, to: :delivered,
                  after: :set_delivered_at
    end

    event :mark_rto do
      transitions from: :shipped, to: :rto,
                  after: :set_rto_at
    end

    event :cancel do
      transitions from: [ :high_risk, :pending_verification, :address_mismatch ], to: :cancelled
    end
  end

  private

  def current_tier_rates
    WEIGHT_TIERS.each do |max_weight, rates|
      return rates if weight_grams <= max_weight
    end
    WEIGHT_TIERS[5000]
  end

  def log_order_event
    triggered = pending_event_triggered_by.presence || "system"
    meta = (pending_event_metadata || {}).stringify_keys
    self.pending_event_triggered_by = nil
    self.pending_event_metadata = nil

    order_events.create!(
      from_state: aasm.from_state&.to_s,
      to_state: aasm.to_state.to_s,
      event_name: aasm.current_event.to_s.delete_suffix("!"),
      triggered_by: triggered,
      metadata: meta
    )
  end

  def set_undeliverable_at
    update_columns(undeliverable_at: Time.current)
  end

  def set_buyer_confirmed_at
    update_columns(buyer_confirmed_at: Time.current)
  end

  def set_shipped_at
    update_columns(shipped_at: Time.current)
  end

  def set_delivered_at
    update_columns(delivered_at: Time.current)
  end

  def set_rto_at
    update_columns(rto_at: Time.current)
  end

  def awb_number_present?
    awb_number.present?
  end
end
