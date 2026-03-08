# frozen_string_literal: true

require "set"

require "http/headers"

module HTTP
  # Follows HTTP redirects according to configured policy
  class Redirector
    # Notifies that we reached max allowed redirect hops
    class TooManyRedirectsError < ResponseError; end

    # Notifies that following redirects got into an endless loop
    class EndlessRedirectError < TooManyRedirectsError; end

    # HTTP status codes which indicate redirects
    REDIRECT_CODES = [300, 301, 302, 303, 307, 308].to_set.freeze

    # Codes which which should raise StateError in strict mode if original
    # request was any of {UNSAFE_VERBS}
    STRICT_SENSITIVE_CODES = [300, 301, 302].to_set.freeze

    # Insecure http verbs, which should trigger StateError in strict mode
    # upon {STRICT_SENSITIVE_CODES}
    UNSAFE_VERBS = %i[put delete post].to_set.freeze

    # Verbs which will remain unchanged upon See Other response.
    SEE_OTHER_ALLOWED_VERBS = %i[get head].to_set.freeze

    # Returns redirector policy
    #
    # @example
    #   redirector.strict # => true
    #
    # @return [Boolean]
    # @api public
    attr_reader :strict

    # Returns maximum allowed hops
    #
    # @example
    #   redirector.max_hops # => 5
    #
    # @return [Fixnum]
    # @api public
    attr_reader :max_hops

    # Initializes a new Redirector
    #
    # @example
    #   HTTP::Redirector.new(strict: true, max_hops: 5)
    #
    # @param [Hash] opts
    # @option opts [Boolean] :strict (true) redirector hops policy
    # @option opts [#to_i] :max_hops (5) maximum allowed amount of hops
    # @api public
    # @return [HTTP::Redirector]
    def initialize(opts = {})
      @strict      = opts.fetch(:strict, true)
      @max_hops    = Integer(opts.fetch(:max_hops, 5))
      @on_redirect = opts.fetch(:on_redirect, nil)
    end

    # Follows redirects until non-redirect response found
    #
    # @example
    #   redirector.perform(request, response) { |req| client.perform(req) }
    #
    # @param [HTTP::Request] request
    # @param [HTTP::Response] response
    # @api public
    # @return [HTTP::Response]
    def perform(request, response, &block)
      @request  = request
      @response = response
      @visited  = []
      collect_cookies_from_request
      collect_cookies_from_response

      follow_redirects(&block) while REDIRECT_CODES.include?(@response.code)

      @response
    end

    private

    # Perform a single redirect step
    #
    # @api private
    # @return [void]
    def follow_redirects
      @visited << "#{@request.verb} #{@request.uri}"

      raise TooManyRedirectsError if too_many_hops?
      raise EndlessRedirectError  if endless_loop?

      @response.flush

      @request = redirect_to(redirect_uri)
      apply_cookies_to_request
      @on_redirect&.call @response, @request
      @response = yield @request
      collect_cookies_from_response
    end

    # Apply cookies to the current request
    #
    # @api private
    # @return [void]
    def apply_cookies_to_request
      return if cookie_jar.empty?

      @request.headers.set(Headers::COOKIE, cookie_jar.map { |c| "#{c.name}=#{c.value}" }.join("; "))
    end

    # Extracts the redirect URI from the Location header
    #
    # @api private
    # @return [String, nil] URI string or nil if no Location header
    def redirect_uri
      location = @response.headers.get(Headers::LOCATION)
      location.join unless location.empty?
    end

    # Returns the cookie jar for tracking cookies
    #
    # @api private
    # @return [HTTP::CookieJar]
    def cookie_jar
      # it seems that @response.cookies instance is reused between responses, so we have to "clone"
      @cookie_jar ||= CookieJar.new
    end

    # Collects cookies from the current request
    #
    # @api private
    # @return [void]
    def collect_cookies_from_request
      request_cookie_header = @request["Cookie"]
      cookies = Cookie.cookie_value_to_hash(request_cookie_header.to_s)

      cookies.each do |key, value|
        cookie_jar.add(Cookie.new(key, value, path: @request.uri.path, domain: @request.host))
      end
    end

    # Carries cookies from response to the next request
    #
    # @api private
    # @return [void]
    def collect_cookies_from_response
      # Overwrite previous cookies
      @response.cookies.each do |cookie|
        if cookie.value == ""
          cookie_jar.delete(cookie)
        else
          cookie_jar.add(cookie)
        end
      end

      # I wish we could just do @response.cookes = cookie_jar
      cookie_jar.each do |cookie|
        @response.cookies.add(cookie)
      end
    end

    # Check if we reached max amount of redirect hops
    #
    # @api private
    # @return [Boolean]
    def too_many_hops?
      @max_hops.positive? && @visited.length > @max_hops
    end

    # Check if we got into an endless loop
    #
    # @api private
    # @return [Boolean]
    def endless_loop?
      @visited.count(@visited.last) > 1
    end

    # Redirect policy for follow
    #
    # @api private
    # @return [Request]
    def redirect_to(uri)
      raise StateError, "no Location header in redirect" unless uri

      verb = @request.verb
      code = @response.code

      if UNSAFE_VERBS.include?(verb) && STRICT_SENSITIVE_CODES.include?(code)
        raise StateError, "can't follow #{@response.status} redirect" if @strict

        verb = :get
      end

      verb = :get if !SEE_OTHER_ALLOWED_VERBS.include?(verb) && 303 == code

      @request.redirect(uri, verb)
    end
  end
end
