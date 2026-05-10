# frozen_string_literal: true

# Helpers for seller-driven verification (dashboard-created orders).
# Automated WhatsApp flow uses +verification_gates+ and jobs; this concern
# only exposes predicates for the manual checklist UI and interactors.
module Orders
  module SellerManualFlow
    extend ActiveSupport::Concern

    MANUAL_RISK_EVENT = "seller_manual_risk_completed"
    MANUAL_ADDRESS_EVENT = "seller_manual_address_completed"
    MANUAL_ADVANCE_LINK_EVENT = "seller_manual_advance_link_created"
    MANUAL_ADVANCE_RECEIVED_EVENT = "seller_manual_advance_marked_received"

    def seller_manual_verification?
      seller_manual?
    end

    def seller_manual_risk_completed?
      order_events.exists?(event_name: MANUAL_RISK_EVENT)
    end

    # Step 2 is complete only after Google validation reached a shippable confidence
    # and we recorded +seller_manual_address_completed+ (not failed/unknown-only).
    def seller_manual_deliverable_address?
      addr = buyer_address
      addr.present? &&
        addr.validated_at.present? &&
        addr.address_confidence.in?(%w[high medium low])
    end

    def seller_manual_address_completed?
      seller_manual_deliverable_address? &&
        order_events.exists?(event_name: MANUAL_ADDRESS_EVENT)
    end

    def seller_manual_address_needs_correction?
      seller_manual? &&
        seller_manual_risk_completed? &&
        !seller_manual_address_completed? &&
        buyer_address&.validated_at.present? &&
        buyer_address.address_confidence.in?(%w[failed unknown])
    end

    def seller_manual_advance_link_created?
      order_events.exists?(event_name: MANUAL_ADVANCE_LINK_EVENT)
    end

    def seller_manual_advance_marked_received?
      order_events.exists?(event_name: MANUAL_ADVANCE_RECEIVED_EVENT)
    end

    def seller_manual_cod_advance_expected?
      seller_manual? && full_cod? && product&.cod_minimum_advance.to_d.positive?
    end
  end
end
