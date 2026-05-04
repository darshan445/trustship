class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.app[:support_email]
  layout "mailer"
end
