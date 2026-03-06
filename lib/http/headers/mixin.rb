# frozen_string_literal: true

require "forwardable"

module HTTP
  class Headers
    # Provides shared behavior for {HTTP::Request} and {HTTP::Response}.
    # Expects `@headers` to be an instance of {HTTP::Headers}.
    #
    # @example Usage
    #
    #   class MyHttpRequest
    #     include HTTP::Headers::Mixin
    #
    #     def initialize
    #       @headers = HTTP::Headers.new
    #     end
    #   end
    module Mixin
      extend Forwardable

      # The HTTP headers collection
      #
      # @example
      #   request.headers
      #
      # @return [HTTP::Headers]
      # @api public
      attr_reader :headers

      # @!method [](name)
      #   Returns header value by name
      #
      #   @example
      #     request["Content-Type"]
      #
      #   (see HTTP::Headers#[])
      #   @return [String, Array<String>, nil]
      #   @api public
      def_delegator :headers, :[]

      # @!method []=(name, value)
      #   Sets header value by name
      #
      #   @example
      #     request["Content-Type"] = "text/plain"
      #
      #   (see HTTP::Headers#[]=)
      #   @return [void]
      #   @api public
      def_delegator :headers, :[]=
    end
  end
end
