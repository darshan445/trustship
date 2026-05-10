# frozen_string_literal: true

class Order < ApplicationRecord
  include AASM
  include Orders::SellerManualFlow

  STATUS_FILTER_MAP = {
    "pending" => "pending_verification",
    "high_risk" => "high_risk",
    "confirmed" => "confirmed",
    "green_zone" => "green_zone",
    "shipped" => "shipped",
    "delivered" => "delivered",
    "rto" => "rto"
  }.freeze

  attr_accessor :pending_event_triggered_by, :pending_event_metadata

  belongs_to :seller
  belongs_to :buyer
  belongs_to :buyer_address, optional: true
  belongs_to :product, optional: true
  has_one :order_confirmation, inverse_of: :order, dependent: :destroy
  has_one :order_advance_payment, inverse_of: :order, dependent: :destroy
  has_many :order_events, inverse_of: :order, dependent: :destroy

  enum :payment_type, {
    full_prepaid: "full_prepaid",
    partial_cod: "partial_cod",
    full_cod: "full_cod"
  }, default: :full_cod

  enum :verification_mode, {
    whatsapp_automated: "whatsapp_automated",
    seller_manual: "seller_manual"
  }, default: :whatsapp_automated

  validates :product_name, presence: true
  validates :amount, presence: true
  validates :buyer_address, presence: true

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
      transitions from: :pending_verification, to: :undeliverable
    end

    event :mark_high_risk do
      transitions from: :pending_verification, to: :high_risk
    end

    event :confirm do
      transitions from: [ :pending_verification, :high_risk ], to: :confirmed
    end

    event :mark_address_mismatch do
      transitions from: :pending_verification, to: :address_mismatch
    end

    event :enter_green_zone do
      transitions from: :confirmed, to: :green_zone
    end

    event :ship do
      transitions from: :green_zone, to: :shipped
    end

    event :mark_delivered do
      transitions from: :shipped, to: :delivered
    end

    event :mark_rto do
      transitions from: :shipped, to: :rto
    end

    event :cancel do
      transitions from: [ :high_risk, :pending_verification, :address_mismatch ], to: :cancelled
    end
  end

  private

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

end
