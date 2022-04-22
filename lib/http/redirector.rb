# frozen_string_literal: true

require "set"

require "http/headers"

module HTTP
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

    # @!attribute [r] strict
    #   Returns redirector policy.
    #   @return [Boolean]
    attr_reader :strict

    # @!attribute [r] max_hops
    #   Returns maximum allowed hops.
    #   @return [Fixnum]
    attr_reader :max_hops

    # @param [Hash] opts
    # @option opts [Boolean] :strict (true) redirector hops policy
    # @option opts [#to_i] :max_hops (5) maximum allowed amount of hops
    def initialize(opts = {})
      @strict   = opts.fetch(:strict, true)
      @max_hops = opts.fetch(:max_hops, 5).to_i
    end

    # Follows redirects until non-redirect response found
    def perform(request, response)
      @request  = request
      @response = response
      @visited  = []

      while REDIRECT_CODES.include? @response.status.code
        @visited << "#{@request.verb} #{@request.uri}"

        raise TooManyRedirectsError if too_many_hops?
        raise EndlessRedirectError  if endless_loop?

        @response.flush

        # XXX(ixti): using `Array#inject` to return `nil` if no Location header.
        @request = redirect_to(@response.headers.get(Headers::LOCATION).inject(:+))
        self.class.update_cookies(@response, @request)
        @response = yield @request
      end

      @response
    end

    class << self
      # Used internally to update cookies between redirects. If a redirct response contains
      # a Set-Cookie header(s), the following request should have that cookie set.
      #
      # The `request` parameter is modified (no return value).
      def update_cookies(response, request)
        request_cookie_header = request.headers["Cookie"]
        cookies =
          if request_cookie_header
            HTTP::Cookie.cookie_value_to_hash(request_cookie_header)
          else
            {}
          end
        cookies = overwrite_cookies(response.cookies, cookies)

        request.headers[Headers::COOKIE] = cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
      end

      def overwrite_cookies(from, into_h)
        from.each do |cookie|
          if cookie.value == ""
            into_h.delete(cookie.name)
          else
            into_h[cookie.name] = cookie.value
          end
        end
        into_h
      end
    end

    private

    # Check if we reached max amount of redirect hops
    # @return [Boolean]
    def too_many_hops?
      1 <= @max_hops && @max_hops < @visited.count
    end

    # Check if we got into an endless loop
    # @return [Boolean]
    def endless_loop?
      2 <= @visited.count(@visited.last)
    end

    # Redirect policy for follow
    # @return [Request]
    def redirect_to(uri)
      raise StateError, "no Location header in redirect" unless uri

      verb = @request.verb
      code = @response.status.code

      if UNSAFE_VERBS.include?(verb) && STRICT_SENSITIVE_CODES.include?(code)
        raise StateError, "can't follow #{@response.status} redirect" if @strict

        verb = :get
      end

      verb = :get if !SEE_OTHER_ALLOWED_VERBS.include?(verb) && 303 == code

      @request.redirect(uri, verb)
    end
  end
end
