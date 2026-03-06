# frozen_string_literal: true

module HTTP
  # Retriable performance ran out of attempts
  class OutOfRetriesError < Error
    # The last response received before failure
    #
    # @example
    #   error.response
    #
    # @return [HTTP::Response, nil] the last response received
    # @api public
    attr_accessor :response

    # Set the underlying exception
    #
    # @example
    #   error.cause = original_error
    #
    # @return [Exception, nil]
    # @api public
    attr_writer :cause

    # Returns the cause of the error
    #
    # @example
    #   error.cause
    #
    # @api public
    # @return [Exception, nil]
    def cause
      @cause || super
    end
  end
end
