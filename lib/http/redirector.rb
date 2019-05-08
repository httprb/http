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

    # @!attribute [r] max_hops
    #   Returns maximum repeats.
    #   @return [Fixnum]
    attr_reader :max_repeats

    # @param [Hash] opts
    # @option opts [Boolean] :strict (true) redirector hops policy
    # @option opts [#to_i] :max_hops (5) maximum allowed amount of hops
    # @option opts [#to_i] :max_repeats if set, stop after a limit of repeats
    def initialize(opts = {}) # rubocop:disable Style/OptionHash
      @strict = opts.fetch(:strict, true)
      @max_repeats = opts.fetch(:max_repeats, 0).to_i
      @max_hops = [opts.fetch(:max_hops, 5).to_i, @max_repeats].max
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
        break if max_repeats?

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
      1 <= @max_hops && @max_hops < @visited.count
    end

    # Check if we got into an endless loop
    # @return [Boolean]
    def endless_loop?
      [2, @max_repeats].max <= @visited.count(@visited.last)
    end

    # Check if we have a max repeats limit
    # @return [Boolean]
    def max_repeats?
      1 <= @max_repeats && @max_repeats <= @visited.count
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
