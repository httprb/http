# frozen_string_literal: true

module HTTP
  # Strict Base64 encoding utilities
  module Base64
    module_function

    # Encode data using strict Base64 encoding
    #
    # @example
    #   HTTP::Base64.encode64("hello")
    #
    # @param input [String] data to encode
    #
    # @return [String]
    #
    # @api private
    def encode64(input)
      [input].pack("m0")
    end
  end
end
