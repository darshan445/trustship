# frozen_string_literal: true

module Sellers
  class SessionsController < Devise::SessionsController
    layout "auth"

    protected

    def after_sign_in_path_for(_resource)
      dashboard_path
    end
  end
end
