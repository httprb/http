# frozen_string_literal: true
module HTTP
  # Printer for {HTTP::Request} and {HTTP::Response}.
  # Expects `print_headline` method to be implemented.
  #
  # @example Usage
  #
  #   class MyHttpRequest
  #     include HTTP::Printer
  #
  #     def print_headline
  #       "MyHttpRequest headline"
  #     end
  #   end
  module Printer
    # Returns human-readable representation including headers.
    #
    # @return [String]
    def inspect
      "#<#{pretty_print(:skip_headers => false)}>"
    end

    # Returns a printable representation of headers.
    # @option [Hash] options
    #   @param [Boolean] skip_headers
    #   @param [Boolean] skip_body
    #   @param [String] separator
    # @return [String]
    def pretty_print(skip_headers: true, skip_body: true, separator: ", ")
      StringIO.open do |io|
        io << print_headline
        io << "#{separator}#{headers.pretty_print(separator)}" unless skip_headers
        io << "#{separator}#{body}" unless skip_body || skip_headers
        io.string
      end
    end

    private

    def print_headline
      raise NotImplementedError, "'print_headline' method must be implemented by classes/modules that include HTTP::Printer module"
    end
  end
end
