# frozen_string_literal: true

module Sellers
  class RegistrationsController < Devise::RegistrationsController
    layout "auth"

    before_action :configure_sign_up_params, only: [ :create ]

    protected

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name phone business_name])
    end

    def after_sign_up_path_for(_resource)
      dashboard_path
    end
  end
end
