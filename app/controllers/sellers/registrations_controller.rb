# frozen_string_literal: true

module Sellers
  class RegistrationsController < Devise::RegistrationsController
    layout "auth"

    before_action :configure_sign_up_params, only: [ :create ]

    def create
      unless params.dig(:seller, :terms_accepted) == "1"
        build_resource(sign_up_params)
        resource.errors.add(:base, "Please accept the terms and conditions to continue")
        clean_up_passwords(resource)
        set_minimum_password_length
        render :new, status: :unprocessable_entity
        return
      end

      super
      return unless resource.persisted?

      resource.update_columns(terms_accepted: true, terms_accepted_at: Time.current)
    end

    protected

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name phone business_name])
    end

    def after_sign_up_path_for(_resource)
      dashboard_path
    end
  end
end
