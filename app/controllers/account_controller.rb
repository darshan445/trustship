# frozen_string_literal: true

class AccountController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!

  def show
    render :index
  end

  def edit
    @seller = current_seller
  end

  def update
    @seller = current_seller
    permitted = seller_params.to_h.symbolize_keys.compact

    result = Sellers::UpdateProfile.execute(seller_id: current_seller.id, **permitted)

    if result.success?
      redirect_to account_path, notice: "Profile updated successfully"
    else
      @seller.assign_attributes(seller_params)
      flash.now[:alert] = result.errors.to_s
      render :edit, status: :unprocessable_entity
    end
  end

  def retry_delhivery_registration
    result = Delhivery::RegisterPickupLocation.execute(seller_id: current_seller.id)
    if result.success?
      redirect_to account_path, notice: "Pickup location registered successfully! You can now ship orders."
    else
      redirect_to account_path, alert: "Registration failed: #{result.errors}. Please try again."
    end
  end

  private

  def seller_params
    params.require(:seller).permit(
      :name, :business_name,
      :pickup_address_line, :pickup_city, :pickup_state, :pickup_pincode,
      :pickup_name, :pickup_phone, :delhivery_pickup_location_name
    )
  end
end
