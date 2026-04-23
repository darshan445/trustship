# frozen_string_literal: true

# MyFeature::DoSomething Interactor
# Purpose: [DESCRIBE WHAT THIS INTERACTOR DOES]
# Methods:
# - execute

class MyFeature::DoSomething
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
      # Your code here.
      # The last line of this block becomes result.data on success.
      # Use raise_string_error("msg") or validate_result(Other.execute(...)) for failures.
      argument
    end
  end

  private

  attr_reader :argument
end
