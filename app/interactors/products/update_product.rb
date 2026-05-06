# frozen_string_literal: true

module Products
  class UpdateProduct
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(product:, params:)
      new(product: product, params: params).execute
    end

    def initialize(product:, params:)
      @product = product
      @params = params || {}
    end

    def execute
      execute_log_and_return_open_struct do
        product.assign_attributes(filtered_params)
        validate_product!(product)
        product.save!
        product
      end
    end

    private

    attr_reader :product, :params

    def filtered_params
      p = params.respond_to?(:to_h) ? params.to_h : params
      p.symbolize_keys.slice(:name, :description, :price, :cod_minimum_advance, :sku, :is_active)
    end

    def validate_product!(record)
      raise_string_error("Name can't be blank") if record.name.to_s.strip.blank?
      raise_string_error("Price must be greater than or equal to 0") if record.price.present? && record.price.to_d.negative?
      if record.cod_minimum_advance.present? && record.cod_minimum_advance.to_d.negative?
        raise_string_error("COD minimum advance must be greater than or equal to 0")
      end
    end
  end
end
