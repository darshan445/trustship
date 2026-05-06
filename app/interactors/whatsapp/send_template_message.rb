# frozen_string_literal: true

module Whatsapp
  class SendTemplateMessage
    include ExecuteMethodHelper
    include LogHelper

    def self.execute(to:, template_name:, parameters:)
      new(to: to, template_name: template_name, parameters: parameters).execute
    end

    def initialize(to:, template_name:, parameters:)
      @to = to
      @template_name = template_name
      @parameters = parameters
    end

    def execute
      execute_log_and_return_open_struct do
        validate_result(
          Whatsapp::SendMessage.execute(
            phone: to,
            template_name: template_name,
            parameters: parameters
          )
        ).data
      end
    end

    private

    attr_reader :to, :template_name, :parameters
  end
end
