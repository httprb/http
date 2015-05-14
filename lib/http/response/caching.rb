require "http/cache/headers"
require "http/response/string_body"
require "http/response/io_body"

module HTTP
  class Response
    # Decorator class for responses to provide convenience methods
    # related to caching.
    class Caching < DelegateClass(HTTP::Response)
      CACHEABLE_RESPONSE_CODES = [200, 203, 300, 301, 410].freeze

      def initialize(obj)
        super
        @requested_at = nil
        @received_at  = nil
      end

      # @return [HTTP::Response::Caching]
      def caching
        self
      end

      # @return [Boolean] true iff this response is stale
      def stale?
        expired? || cache_headers.must_revalidate?
      end

      # @returns [Boolean] true iff this response has expired
      def expired?
        current_age >= cache_headers.max_age
      end

      # @return [Boolean] true iff this response is cacheable
      #
      # ---
      # A Vary header field-value of "*" always fails to match and
      # subsequent requests on that resource can only be properly
      # interpreted by the
      def cacheable?
        @cacheable ||=
          begin
            CACHEABLE_RESPONSE_CODES.include?(code) \
              && !(cache_headers.vary_star? ||
                   cache_headers.no_store?  ||
                   cache_headers.no_cache?)
          end
      end

      # @return [Numeric] the current age (in seconds) of this response
      #
      # ---
      # Algo from https://tools.ietf.org/html/rfc2616#section-13.2.3
      def current_age
        now = Time.now
        age_value  = headers.get("Age").map(&:to_i).max || 0

        apparent_age = [0, received_at - server_response_time].max
        corrected_received_age = [apparent_age, age_value].max
        response_delay = [0, received_at - requested_at].max
        corrected_initial_age = corrected_received_age + response_delay
        resident_time = [0, now - received_at].max

        corrected_initial_age + resident_time
      end

      # @return [Time] the time at which this response was requested
      def requested_at
        @requested_at ||= received_at
      end
      attr_writer :requested_at

      # @return [Time] the time at which this response was received
      def received_at
        @received_at ||= Time.now
      end
      attr_writer :received_at

      # Update self based on this response being revalidated by the
      # server.
      def validated!(validating_response)
        headers.merge!(validating_response.headers)
        self.requested_at  = validating_response.requested_at
        self.received_at   = validating_response.received_at
      end

      # @return [HTTP::Cache::Headers] cache control headers helper object.
      def cache_headers
        @cache_headers ||= HTTP::Cache::Headers.new headers
      end

      def body
        @body ||= if __getobj__.body.respond_to? :each
                    __getobj__.body
                  else
                    StringBody.new(__getobj__.body.to_s)
                  end
      end

      def body=(new_body)
        @body = if new_body.respond_to?(:readpartial) && new_body.respond_to?(:read)
                  # IO-ish, probably a rack cache response body
                  IoBody.new(new_body)

                elsif new_body.respond_to? :join
                  # probably an array of body parts (rack cache does this sometimes)
                  StringBody.new(new_body.join(""))

                elsif new_body.respond_to? :readpartial
                  # normal body, just use it.
                  new_body

                else
                  # backstop, just to_s it
                  StringBody.new(new_body.to_s)
                end
      end

      def vary
        headers.get("Vary").first
      end

      protected

      # @return [Time] the time at which the server generated this response.
      def server_response_time
        headers.get("Date").
          map(&method(:to_time_or_epoch)).
          max || begin
                    # set it if it is not already set
                    headers["Date"] = received_at.httpdate
                    received_at
                  end
      end

      def to_time_or_epoch(t_str)
        Time.httpdate(t_str)
      rescue ArgumentError
        Time.at(0)
      end
    end
  end
end
