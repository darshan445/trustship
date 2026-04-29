# frozen_string_literal: true

module Sellers
  class UpdateProfile
    include ExecuteMethodHelper
    include LogHelper

    UPDATE_KEYS = %i[
      name business_name pickup_address_line pickup_city pickup_state pickup_pincode
      pickup_name pickup_phone delhivery_pickup_location_name
    ].freeze

    def self.execute(seller_id:, **attrs)
      new(seller_id: seller_id, **attrs).execute
    end

    def initialize(seller_id:, **attrs)
      @seller_id = seller_id
      @attrs = attrs.slice(*UPDATE_KEYS).compact
    end

    def execute
      execute_log_and_return_open_struct do
        seller = find_seller!

        if @attrs.key?(:pickup_pincode)
          pc = @attrs[:pickup_pincode].to_s
          if pc.present? && !pc.match?(/\A\d{6}\z/)
            raise_string_error("Pickup pincode must be 6 digits")
          end
        end

        seller.assign_attributes(@attrs)
        unless seller.save
          raise_string_error(seller.errors.full_messages.join(", "))
        end

        register_pickup_with_delhivery_if_needed(seller)

        seller
      end
    end

    private

    attr_reader :seller_id, :attrs

    def register_pickup_with_delhivery_if_needed(seller)
      pickup_fields_changed = %i[
        pickup_address_line
        pickup_city
        pickup_state
        pickup_pincode
      ].any? { |field| seller.saved_change_to_attribute?(field) }
      return unless pickup_fields_changed && seller.pickup_address_saved?

      registration_result = Delhivery::RegisterPickupLocation.execute(seller_id: seller.id)
      return if registration_result.success?

      Rails.logger.error do
        "Delhivery pickup registration failed for seller #{seller.id}: #{registration_result.errors}"
      end
    end

    def find_seller!
      seller = Seller.find_by(id: seller_id)
      raise_string_error("Seller not found") if seller.blank?

      seller
    end
  end
end
