# frozen_string_literal: true

class AdminController < ApplicationController
  layout "admin"

  before_action :authenticate_admin!

  def index
    @sellers = Seller.order(created_at: :desc)
                     .select(:id, :name, :email, :phone, :business_name, :status,
                             :early_access, :whatsapp_onboarding_status,
                             :whatsapp_display_phone_number, :created_at)

    @total_sellers    = @sellers.size
    @active_sellers   = @sellers.count { |s| s.status == "active" }
    @wa_connected     = @sellers.count { |s| s.whatsapp_onboarding_status == "connected" }
  end

  private

  def authenticate_admin!
    expected = Rails.application.credentials.dig(:admin, :key).presence
    provided = params[:key].presence

    return if expected && provided && ActiveSupport::SecurityUtils.secure_compare(expected, provided)

    head :forbidden
  end
end
