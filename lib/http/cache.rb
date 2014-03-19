require 'time'

module HTTP
  class Cache
    CACHEABLE_METHODS        = [:get, :head].freeze
    INVALIDATING_METHODS     = [:post, :put, :delete].freeze
    CACHEABLE_RESPONSE_CODES = [200, 203, 300, 301, 410].freeze
    ALLOWED_CACHE_MODES      = [:public, :private].freeze

    class CacheModeError < CacheError; end

    attr_reader :request, :response

    def initialize(options)
      unless ALLOWED_CACHE_MODES.include?(options.cache[:mode])
        fail CacheModeError, "Invalid cache_mode #{options.cache[:mode]} supplied"
      end
      @cache_mode    = options.cache[:mode]
      @cache_adapter = options.cache[:adapter]
    end

    def perform_request(request)
      @request = request

      if @response = @cached_response = cache_lookup
        if forces_cache_deletion?(request)
          invalidate_cache
        elsif needs_revalidation?
          set_validation_headers!
        else
          @cached_response
        end
      else
        nil
      end
    end

    def perform_response(response)
      @response = response
      response.request_time  = request.request_time
      response.authoritative = true
      # RFC2618 - 14.18 : A received message that does not have a Date header
      # field MUST be assigned one by the recipient if the message will be cached
      # by that recipient.
      response.headers['Date'] ||= response.response_time.httpdate

      if @cached_response
        if forces_cache_deletion?(response)
          invalidate_cache
        elsif response.reason == 'Not Modified'
          revalidate_response!
        end
      end

      if request_cacheable? && response_cacheable?
        store_in_cache
      elsif invalidates_cache?
        invalidate_cache
      end
    end

    private

    def cache_lookup
      @cache_adapter.lookup(request) unless skip_cache?
    end

    def forces_cache_deletion?(re)
      re.headers['Cache-Control'] && re.headers['Cache-Control'].include?('no-store')
    end

    def needs_revalidation?
      return true if forces_revalidation?
      return true if stale?
      return true if max_age && current_age > max_age
      return true if must_be_revalidated?
      false
    end

    def forces_revalidation?
      max_age == 0 || skip_cache?
    end

    def max_age
      if request.headers['Cache-Control'] && request.headers['Cache-Control'].include?('max-age')
        request.headers['Cache-Control'].split(',').grep(/max-age/).first.split('=').last.to_i
      end
    end

    def skip_cache?
      return true unless CACHEABLE_METHODS.include?(request.verb)
      return false unless request.headers['Cache-Control']
      request.headers['Cache-Control'].include?('no-cache')
    end

    # Algo from https://tools.ietf.org/html/rfc2616#section-13.2.3
    def current_age
      now = Time.now
      age_value  = response.headers['Age'].to_i
      date_value = Time.httpdate(response.headers['Date'])

      apparent_age = [0, response.response_time - date_value].max
      corrected_received_age = [apparent_age, age_value].max
      response_delay = response.response_time - response.request_time
      corrected_initial_age = corrected_received_age + response_delay
      resident_time = now - response.response_time
      corrected_initial_age + resident_time
    end

    def set_validation_headers!
      if response.headers['Etag']
        request.headers['If-None-Match'] = response.headers['Etag']
      end
      if response.headers['Last-Modified']
        request.headers['If-Modified-Since'] = response.headers['Last-Modified']
      end
      request.headers['Cache-Control'] = 'max-age=0' if must_be_revalidated?
      nil
    end

    def revalidate_response!
      @cached_response.headers.merge!(response.headers)
      @cached_response.request_time  = response.request_time
      @cached_response.response_time = response.response_time
      @cached_response.authoritative = true
      @response = @cached_response
    end

    def request_cacheable?
      return false unless response.status.between?(200, 299)
      return false unless CACHEABLE_METHODS.include?(request.verb)
      return false if request.headers['Cache-Control'] && request.headers['Cache-Control'].include?('no-store')
      true
    end

    def response_cacheable?
      return @cacheable if @cacheable

      if CACHEABLE_RESPONSE_CODES.include?(response.code)
        @cacheable = true

        if response.headers['Cache-Control']
          @cacheable = :public  if response.headers['Cache-Control'].include?('public')
          @cacheable = :private if response.headers['Cache-Control'].include?('private')
          @cacheable = false    if response.headers['Cache-Control'].include?('no-cache')
          @cacheable = false    if response.headers['Cache-Control'].include?('no-store')
        end

        # A Vary header field-value of "*" always fails to match
        # and subsequent requests on that resource can only be properly interpreted by the origin server.
        @cacheable = false if response.headers['Vary'] && response.headers['Vary'].include?('*')
      else
        @cacheable = false
      end

      unless @cacheable == true
        if @cacheable == @cache_mode
          @cacheable = true
        else
          @cacheable = false
        end
      end

      @cacheable
    end

    def store_in_cache
      @cache_adapter.store(request, response)
      nil
    end

    def invalidates_cache?
      INVALIDATING_METHODS.include?(request.verb)
    end

    def invalidate_cache
      @cache_adapter.invalidate(request.uri)
      nil
    end

    def expired?
      if response.headers['Cache-Control'] && m_age_str = response.headers['Cache-Control'].match(/max-age=(\d+)/)
        current_age > m_age_str[1].to_i
      elsif response.headers['Expires']
        begin
          Time.httpdate(response.headers['Expires']) < Time.now
        rescue ArgumentError
          # Some servers only send a "Expire: -1" header which must be treated as expired
          true
        end
      else
        false
      end
    end

    def stale?
      return true if expired?
      return false unless response.headers['Cache-Control']
      return true if response.headers['Cache-Control'].match(/must-revalidate|no-cache/)

      false
    end

    def must_be_revalidated?
      response.headers['Cache-Control'] && response.headers['Cache-Control'].include?('must-revalidate')
    end
  end
end
