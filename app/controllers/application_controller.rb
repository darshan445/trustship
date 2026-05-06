class ApplicationController < ActionController::Base
  include Pagy::Backend
  helper_method :dashboard_sidebar_active, :dashboard_mobile_nav_classes,
                :dashboard_pending_orders_count, :initials_for_business

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def dashboard_sidebar_active(section)
    current =
      case section
      when :orders then controller_name == "orders"
      when :products then controller_name == "products"
      when :buyers then controller_name == "buyers"
      when :settings then controller_name == "account"
      else false
      end
    current ? "active" : ""
  end

  def dashboard_mobile_nav_classes(active)
    base = "flex flex-col items-center gap-0.5 rounded-lg py-1 text-center"
    active ? "#{base} text-[#534AB7]" : "#{base} text-gray-500"
  end

  def dashboard_pending_orders_count
    return 0 unless respond_to?(:current_seller) && current_seller.present?

    @dashboard_pending_orders_count ||= current_seller.orders.where(aasm_state: "pending_verification").count
  end

  def initials_for_business(name)
    return "TS" if name.blank?

    name.split.first(2).map { |part| part.first.to_s.upcase }.join
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name phone business_name])
  end
end
