module ApplicationHelper
  include Pagy::Frontend

  def support_email
    Rails.application.credentials.app[:support_email]
  end

  def founder_email
    Rails.application.credentials.app[:founder_email]
  end

  def app_domain
    Rails.application.credentials.app[:domain]
  end

  def dashboard_sidebar_active(section)
    current =
      case section
      when :orders then controller_name == "orders"
      when :products then controller_name == "products"
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
end
