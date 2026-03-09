# frozen_string_literal: true

module HTTP
  module Chainable
    # HTTP verb shortcut methods
    #
    # Each method delegates to {Chainable#request} with the appropriate verb.
    module Verbs
      # Request a get sans response body
      #
      # @example
      #   HTTP.head("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def head(uri, options = {})
        request :head, uri, options
      end

      # Get a resource
      #
      # @example
      #   HTTP.get("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def get(uri, options = {})
        request :get, uri, options
      end

      # Post to a resource
      #
      # @example
      #   HTTP.post("http://example.com", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def post(uri, options = {})
        request :post, uri, options
      end

      # Put to a resource
      #
      # @example
      #   HTTP.put("http://example.com", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def put(uri, options = {})
        request :put, uri, options
      end

      # Delete a resource
      #
      # @example
      #   HTTP.delete("http://example.com/resource")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def delete(uri, options = {})
        request :delete, uri, options
      end

      # Echo the request back to the client
      #
      # @example
      #   HTTP.trace("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def trace(uri, options = {})
        request :trace, uri, options
      end

      # Return the methods supported on the given URI
      #
      # @example
      #   HTTP.options("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def options(uri, options = {})
        request :options, uri, options
      end

      # Convert to a transparent TCP/IP tunnel
      #
      # @example
      #   HTTP.connect("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def connect(uri, options = {})
        request :connect, uri, options
      end

      # Apply partial modifications to a resource
      #
      # @example
      #   HTTP.patch("http://example.com/resource", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param [Hash] options request options
      # @return [HTTP::Response]
      # @api public
      def patch(uri, options = {})
        request :patch, uri, options
      end
    end
  end
end
