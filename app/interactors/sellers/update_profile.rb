# frozen_string_literal: true

module Sellers
  class UpdateProfile
    include ExecuteMethodHelper
    include LogHelper

    UPDATE_KEYS = %i[name business_name].freeze

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

        seller.assign_attributes(@attrs)
        unless seller.save
          raise_string_error(seller.errors.full_messages.join(", "))
        end

        seller
      end
    end

    private

    attr_reader :seller_id, :attrs

    def find_seller!
      seller = Seller.find_by(id: seller_id)
      raise_string_error("Seller not found") if seller.blank?

      seller
    end
  end
end
