# frozen_string_literal: true

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
    # @param [Boolean] strict (true) redirector hops policy
    # @param [#to_i] max_hops (5) maximum allowed amount of hops
    # @param [#call, nil] on_redirect optional redirect callback
    # @api public
    # @return [HTTP::Redirector]
    def initialize(strict: true, max_hops: 5, on_redirect: nil)
      @strict      = strict
      @max_hops    = Integer(max_hops)
      @on_redirect = on_redirect
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
    def perform(request, response, &)
      @request  = request
      @response = response
      @visited  = []

      follow_redirects(&) while REDIRECT_CODES.include?(@response.code)

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
      @on_redirect&.call @response, @request
      @response = yield @request
    end

    # Extracts the redirect URI from the Location header
    #
    # @api private
    # @return [String, nil] URI string or nil if no Location header
    def redirect_uri
      location = @response.headers.get(Headers::LOCATION)
      location.join unless location.empty?
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
