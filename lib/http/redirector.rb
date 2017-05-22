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
    UNSAFE_VERBS = [:put, :delete, :post].to_set.freeze

    # Verbs which will remain unchanged upon See Other response.
    SEE_OTHER_ALLOWED_VERBS = [:get, :head].to_set.freeze

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
    def initialize(opts = {}) # rubocop:disable Style/OptionHash
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

        @request  = redirect_to @response.headers[Headers::LOCATION]
        @response = yield @request
      end

      @response
    end

    private

    # Check if we reached max amount of redirect hops
    # @return [Boolean]
    def too_many_hops?
      @max_hops > 0 && @visited.count > @max_hops
    end

    # Check if we got into an endless loop
    # @return [Boolean]
    def endless_loop?
      @visited.count(@visited.last) > 1
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

      verb = :get if !SEE_OTHER_ALLOWED_VERBS.include?(verb) && code == 303

      @request.redirect(uri, verb)
    end
  end
end
