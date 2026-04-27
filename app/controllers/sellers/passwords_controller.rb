# frozen_string_literal: true

module Sellers
  class PasswordsController < Devise::PasswordsController
    layout "auth"

    private

    def resource_params
      case action_name
      when "create"
        params.require(:seller).permit(:phone)
      when "update"
        params.require(:seller).permit(:reset_password_token, :password, :password_confirmation)
      else
        super
      end
    end
  end
end
