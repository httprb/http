# frozen_string_literal: true

require "time"

module HTTP
  module Features
    class Caching < Feature
      # A cached response entry with freshness logic
      class Entry
        # The HTTP status code
        #
        # @example
        #   entry.status # => 200
        #
        # @return [Integer] the HTTP status code
        # @api public
        attr_reader :status

        # The HTTP version
        #
        # @example
        #   entry.version # => "1.1"
        #
        # @return [String] the HTTP version
        # @api public
        attr_reader :version

        # The response headers
        #
        # @example
        #   entry.headers
        #
        # @return [HTTP::Headers] the response headers
        # @api public
        attr_reader :headers

        # The proxy headers from the original response
        #
        # @example
        #   entry.proxy_headers
        #
        # @return [HTTP::Headers] the proxy headers
        # @api public
        attr_reader :proxy_headers

        # The response body as a string
        #
        # @example
        #   entry.body # => "<html>...</html>"
        #
        # @return [String] the response body
        # @api public
        attr_reader :body

        # The URI of the original request
        #
        # @example
        #   entry.request_uri
        #
        # @return [HTTP::URI] the request URI
        # @api public
        attr_reader :request_uri

        # When the response was stored
        #
        # @example
        #   entry.stored_at
        #
        # @return [Time] when the response was stored
        # @api public
        attr_reader :stored_at

        # Create a new cache entry
        #
        # @example
        #   Entry.new(status: 200, version: "1.1", headers: headers,
        #             proxy_headers: proxy_headers, body: "hello",
        #             request_uri: uri, stored_at: Time.now)
        #
        # @param status [Integer]
        # @param version [String]
        # @param headers [HTTP::Headers]
        # @param proxy_headers [HTTP::Headers]
        # @param body [String]
        # @param request_uri [HTTP::URI]
        # @param stored_at [Time]
        # @return [Entry]
        # @api public
        def initialize(status:, version:, headers:, proxy_headers:, body:, request_uri:, stored_at:)
          @status        = status
          @version       = version
          @headers       = headers
          @proxy_headers = proxy_headers
          @body          = body
          @request_uri   = request_uri
          @stored_at     = stored_at
        end

        # Whether the cached response is still fresh
        #
        # @example
        #   entry.fresh? # => true
        #
        # @return [Boolean]
        # @api public
        def fresh?
          return false if no_cache?

          ttl = max_age
          return age < ttl if ttl

          expires = expires_at
          return Time.now < expires if expires

          false
        end

        # Reset the stored_at time to now (after successful revalidation)
        #
        # @example
        #   entry.revalidate!
        #
        # @return [Time]
        # @api public
        def revalidate!
          @stored_at = Time.now
        end

        # Merge response headers from a 304 revalidation into the stored entry
        #
        # @example
        #   entry.update_headers!(response.headers)
        #
        # @param response_headers [HTTP::Headers]
        # @return [void]
        # @api public
        def update_headers!(response_headers)
          response_headers.each { |name, value| @headers[name] = value } # steep:ignore
        end

        private

        # Age of the entry in seconds
        # @return [Float]
        # @api private
        def age
          Float(Integer(headers[Headers::AGE], exception: false) || 0) + (Time.now - stored_at)
        end

        # max-age value from Cache-Control, if present
        # @return [Integer, nil]
        # @api private
        def max_age
          match = String(headers[Headers::CACHE_CONTROL]).match(/max-age=(\d+)/)
          return unless match

          Integer(match[1])
        end

        # Expiration time from Expires header
        # @return [Time, nil]
        # @api private
        def expires_at
          Time.httpdate(String(headers[Headers::EXPIRES]))
        rescue ArgumentError
          nil
        end

        # Whether the Cache-Control includes no-cache
        # @return [Boolean]
        # @api private
        def no_cache?
          String(headers[Headers::CACHE_CONTROL]).downcase.include?("no-cache")
        end
      end
    end
  end
end
