# frozen_string_literal: true

class ProductsController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!
  before_action :set_product, only: [:edit, :update, :destroy]

  def index
    scope = current_seller.products.order(is_active: :desc, created_at: :desc)
    @pagy, @products = pagy(scope)
  end

  def new
    @product = current_seller.products.new(is_active: true)
  end

  def create
    result = Products::CreateProduct.execute(seller: current_seller, params: product_params)
    if result.success?
      redirect_to products_path, notice: "Product saved."
    else
      @product = current_seller.products.new(product_params)
      flash.now[:alert] = result.errors.to_s
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    result = Products::UpdateProduct.execute(product: @product, params: product_params)
    if result.success?
      redirect_to products_path, notice: "Product updated."
    else
      flash.now[:alert] = result.errors.to_s
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.update!(is_active: !@product.is_active)
    message = @product.is_active? ? "Product enabled." : "Product disabled."
    redirect_to products_path, notice: message
  end

  private

  def set_product
    @product = current_seller.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :cod_minimum_advance, :sku)
  end
end
