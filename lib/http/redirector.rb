module HTTP
  class Redirector
    # Notifies that we reached max allowed redirect hops
    class TooManyRedirectsError < ResponseError; end

    # Notifies that following redirects got into an endless loop
    class EndlessRedirectError < TooManyRedirectsError; end

    # HTTP status codes which indicate redirects
    REDIRECT_CODES = [300, 301, 302, 303, 307, 308].freeze

    # :nodoc:
    def initialize(options = nil)
      options   = {:max_hops => 5, :strict => false} unless options.respond_to?(:fetch)
      @strict   = options.fetch(:strict)
      @max_hops = options.fetch(:max_hops, 5)
      @max_hops = false if @max_hops && 1 > @max_hops.to_i
    end

    # Follows redirects until non-redirect response found
    def perform(request, response, &block)
      reset(request, response)
      follow(&block)
    end

    private

    # Reset redirector state
    def reset(request, response)
      @request, @response = request, response
      @visited = []
    end

    # Follow redirects
    def follow
      while REDIRECT_CODES.include?(@response.code)
        @visited << @request.uri.to_s

        fail TooManyRedirectsError if too_many_hops?
        fail EndlessRedirectError  if endless_loop?

        uri = @response.headers["Location"]
        fail StateError, "no Location header in redirect" unless uri

        fail StateError, "no redirect in strict mode" if no_redirect? && @strict

        @request = @request.redirect uri, :get if no_redirect?

        if 303 == @response.code
          @request = @request.redirect uri, :get
        else
          @request = @request.redirect uri
        end

        @response = yield @request
      end

      @response
    end

    # Check if we reached max amount of redirect hops
    def too_many_hops?
      @max_hops < @visited.count if @max_hops
    end

    # Check if we got into an endless loop
    def endless_loop?
      2 < @visited.count(@visited.last)
    end

    def no_redirect?
      nor_get_or_head? && strict_no_redirect_codes?
    end

    def strict_no_redirect_codes?
      [301, 302, 303].include? @response.code
    end

    def nor_get_or_head?
      @request.verb != :get && @request.verb != :head
    end
  end
end
