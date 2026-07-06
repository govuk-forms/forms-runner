# frozen_string_literal: true

module Flow
  module Errors
    class StepNotFoundError < StandardError
      def initialize(msg = "Step not found.")
        super
      end
    end
  end
end
