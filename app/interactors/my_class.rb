# frozen_string_literal: true

# MyClass Interactor
# Purpose: Example interactor — replace with your own logic.
# Methods:
# - execute

class MyClass
  include ExecuteMethodHelper
  include LogHelper

  def self.execute(argument)
    new(argument).execute
  end

  def initialize(argument)
    @argument = argument
  end

  def execute
    execute_log_and_return_open_struct do
      # Business logic goes here.
      # The LAST expression becomes result.data on success.
      # Call raise_string_error("msg") or validate_result(OtherClass.execute(...))
      # to surface failures — they are caught and become result.errors.
      argument
    end
  end

  private

  attr_reader :argument
end
