# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

class WhatsappController < ApplicationController
  layout "dashboard"

  before_action :authenticate_seller!

  def show
    @seller = current_seller
    @embedded_config_id = embedded_config_id
    @facebook_app_id = facebook_app_id
  end

  def embedded_signup_complete
    waba_id = params[:waba_id].to_s
    phone_number_id = params[:phone_number_id].to_s
    raise "Missing waba_id" if waba_id.blank?
    raise "Missing phone_number_id" if phone_number_id.blank?

    current_seller.update!(
      whatsapp_onboarding_status: "pending",
      whatsapp_waba_id: waba_id,
      whatsapp_phone_number_id: phone_number_id
    )

    details = fetch_phone_details(phone_number_id)
    current_seller.update!(
      whatsapp_display_phone_number: details[:display_phone_number].presence || current_seller.whatsapp_display_phone_number,
      whatsapp_verified_name: details[:verified_name].presence || current_seller.whatsapp_verified_name,
      whatsapp_onboarding_status: "connected",
      whatsapp_linked_at: Time.current
    )

    subscribe_app_to_waba(waba_id)

    render json: { ok: true }, status: :ok
  rescue StandardError => e
    current_seller.update!(whatsapp_onboarding_status: "failed")
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def embedded_config_id
    Rails.application.credentials.dig(:meta, :whatsapp_embedded_config_id).presence
  end

  def facebook_app_id
    Rails.application.credentials.dig(:meta, :facebook_app_id).presence
  end

  def graph_token
    Rails.application.credentials.dig(:meta, :whatsapp_token).presence
  end

  def fetch_phone_details(phone_number_id)
    token = graph_token.to_s
    return {} if token.blank?

    uri = URI("https://graph.facebook.com/v21.0/#{phone_number_id}")
    uri.query = URI.encode_www_form(fields: "display_phone_number,verified_name", access_token: token)
    res = Net::HTTP.get_response(uri)
    return {} unless res.code.to_i == 200

    body = JSON.parse(res.body)
    {
      display_phone_number: body["display_phone_number"],
      verified_name: body["verified_name"]
    }
  rescue StandardError
    {}
  end

  def subscribe_app_to_waba(waba_id)
    token = graph_token.to_s
    return if token.blank?

    uri = URI("https://graph.facebook.com/v21.0/#{waba_id}/subscribed_apps")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(access_token: token)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  rescue StandardError => e
    Rails.logger.warn("Embedded signup subscribed_apps failed: #{e.message}")
  end
end
