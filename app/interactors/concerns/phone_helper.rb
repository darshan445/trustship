# frozen_string_literal: true

module PhoneHelper
  def normalize_phone(phone)
    return nil if phone.blank?

    phone = phone.to_s.strip
    phone = phone.gsub(/\s+/, "")
    phone = phone.gsub(/[-()]/, "")
    phone = phone.sub(/^\+91/, "")
    phone = phone.sub(/^91/, "")
    phone = phone.sub(/^0/, "")
    phone.length == 10 ? phone : nil
  end
end
