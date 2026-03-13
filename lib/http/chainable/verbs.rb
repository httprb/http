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
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def head(uri, **, &)
        request(:head, uri, **, &) # steep:ignore
      end

      # Get a resource
      #
      # @example
      #   HTTP.get("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def get(uri, **, &)
        request(:get, uri, **, &) # steep:ignore
      end

      # Post to a resource
      #
      # @example
      #   HTTP.post("http://example.com", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def post(uri, **, &)
        request(:post, uri, **, &) # steep:ignore
      end

      # Put to a resource
      #
      # @example
      #   HTTP.put("http://example.com", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def put(uri, **, &)
        request(:put, uri, **, &) # steep:ignore
      end

      # Delete a resource
      #
      # @example
      #   HTTP.delete("http://example.com/resource")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def delete(uri, **, &)
        request(:delete, uri, **, &) # steep:ignore
      end

      # Echo the request back to the client
      #
      # @example
      #   HTTP.trace("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def trace(uri, **, &)
        request(:trace, uri, **, &) # steep:ignore
      end

      # Return the methods supported on the given URI
      #
      # @example
      #   HTTP.options("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def options(uri, **, &)
        request(:options, uri, **, &) # steep:ignore
      end

      # Convert to a transparent TCP/IP tunnel
      #
      # @example
      #   HTTP.connect("http://example.com")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def connect(uri, **, &)
        request(:connect, uri, **, &) # steep:ignore
      end

      # Apply partial modifications to a resource
      #
      # @example
      #   HTTP.patch("http://example.com/resource", body: "data")
      #
      # @param [String, URI] uri URI to request
      # @param options [Hash] request options
      # @yieldparam response [HTTP::Response] the response
      # @return [HTTP::Response, Object] the response, or block return value
      # @api public
      def patch(uri, **, &)
        request(:patch, uri, **, &) # steep:ignore
      end
    end
  end
end
