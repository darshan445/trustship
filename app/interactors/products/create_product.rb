# frozen_string_literal: true

module Products
  class CreateProduct
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(seller:, params:)
      new(seller: seller, params: params).execute
    end

    def initialize(seller:, params:)
      @seller = seller
      @params = params || {}
    end

    def execute
      execute_log_and_return_open_struct do
        product = seller.products.new(filtered_params)
        validate_product!(product)
        product.save!
        product
      end
    end

    private

    attr_reader :seller, :params

    def filtered_params
      p = params.respond_to?(:to_h) ? params.to_h : params
      p.symbolize_keys.slice(:name, :description, :price, :cod_minimum_advance, :sku, :is_active)
    end

    def validate_product!(product)
      raise_string_error("Name can't be blank") if product.name.to_s.strip.blank?
      raise_string_error("Price must be greater than or equal to 0") if product.price.present? && product.price.to_d.negative?
      if product.cod_minimum_advance.present? && product.cod_minimum_advance.to_d.negative?
        raise_string_error("COD minimum advance must be greater than or equal to 0")
      end
    end
  end
end
