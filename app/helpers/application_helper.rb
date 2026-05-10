module ApplicationHelper
  include Pagy::Frontend

  def support_email
    Rails.application.credentials.dig(:app, :support_email).to_s.presence
  end

  def founder_email
    Rails.application.credentials.dig(:app, :founder_email).to_s.presence
  end

  def app_domain
    Rails.application.credentials.dig(:app, :domain).to_s.presence
  end
end
