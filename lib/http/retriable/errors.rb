# frozen_string_literal: true

module HTTP
  # Retriable performance ran out of attempts
  class OutOfRetriesError < Error
    attr_accessor :response

    attr_writer :cause

    def cause
      @cause || super
    end
  end
end
