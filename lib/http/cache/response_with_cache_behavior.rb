require "http/response"

module HTTP
  class Cache
    # Decorator class for responses to provide convenience methods
    # related to caching. Instantiate using the `.coerce` method.
    class ResponseWithCacheBehavior < DelegateClass(HTTP::Response)
      CACHEABLE_RESPONSE_CODES = [200, 203, 300, 301, 410].freeze

      class << self
        protected :new

        # Returns a instance of self by wrapping `another` a new
        #  instance of self or by just returning it
        def coerce(another)
          if another.respond_to? :cacheable?
            another
          else
            new(another)
          end
        end
      end

      # Returns true iff this response is stale; otherwise false
      def stale?
        expired? || cache_control.must_revalidate?
      end

      # Returns true iff this response has expired; otherwise false
      def expired?
        current_age > cache_control.max_age
      end

      # Return true iff this response is cacheable; otherwise false
      #
      # ---
      # A Vary header field-value of "*" always fails to match and
      # subsequent requests on that resource can only be properly
      # interpreted by the
      def cacheable?
        @cacheable ||=
          begin
            CACHEABLE_RESPONSE_CODES.include?(code) &&
              !(cache_control.vary_star? ||
                cache_control.no_store?  ||
                cache_control.no_cache?)
          end
      end

      # Returns the current age (in seconds) of this response
      #
      # ---
      # Algo from https://tools.ietf.org/html/rfc2616#section-13.2.3
      def current_age
        now = Time.now
        age_value  = headers.get("Age").map(&:to_i).max || 0

        apparent_age = [0, received_at - server_response_time].max
        corrected_received_age = [apparent_age, age_value].max
        response_delay = received_at - requested_at
        corrected_initial_age = corrected_received_age + response_delay
        resident_time = now - received_at
        corrected_initial_age + resident_time
      end

      # Returns the time at which this response was requested
      def requested_at
        @requested_at ||= Time.now
      end
      attr_writer :requested_at

      # Returns the time at which this response was received
      def received_at
        @received_at || Time.now
      end
      attr_writer :received_at

      # Update self based on this response being revalidated by the
      # server.
      def validated!(validating_response)
        headers.merge!(validating_response.headers)
        self.request_time  = validating_response.request_time
        self.response_time = validating_response.response_time
        self.authoritative = true
      end

      # Returns cache control helper object.
      def cache_control
        @cache_control ||= CacheControl.new(self)
      end

      protected

      # Returns the time at which the server generated this response.
      def server_response_time
        headers.get("Date")
          .map(&method(:to_time_or_epoch))
          .max || begin
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

      def initialize(obj)
        super
        @requested_at = nil
        @received_at  = nil
      end
    end
  end
end
