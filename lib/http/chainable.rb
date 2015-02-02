require "base64"

module HTTP
  module Chainable
    # Request a get sans response body
    # @param uri
    # @option options [Hash]
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource
    # @param uri
    # @option options [Hash]
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource
    # @param uri
    # @option options [Hash]
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource
    # @param uri
    # @option options [Hash]
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource
    # @param uri
    # @option options [Hash]
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client
    # @param uri
    # @option options [Hash]
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI
    # @param uri
    # @option options [Hash]
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel
    # @param uri
    # @option options [Hash]
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource
    # @param uri
    # @option options [Hash]
    def patch(uri, options = {})
      request :patch, uri, options
    end

    # Make an HTTP request with the given verb
    # @param uri
    # @option options [Hash]
    def request(verb, uri, options = {})
      branch(options).request verb, uri
    end

    # Make a request through an HTTP proxy
    # @param [Array] proxy
    # @raise [Request::Error] if HTTP proxy is invalid
    def via(*proxy)
      proxy_hash = {}
      proxy_hash[:proxy_address]  = proxy[0] if proxy[0].is_a?(String)
      proxy_hash[:proxy_port]     = proxy[1] if proxy[1].is_a?(Integer)
      proxy_hash[:proxy_username] = proxy[2] if proxy[2].is_a?(String)
      proxy_hash[:proxy_password] = proxy[3] if proxy[3].is_a?(String)

      if [2, 4].include?(proxy_hash.keys.size)
        branch default_options.with_proxy(proxy_hash)
      else
        fail(RequestError, "invalid HTTP proxy: #{proxy_hash}")
      end
    end
    alias_method :through, :via

    # Alias for with_response(:object)
    def stream
      with_response(:object)
    end

    # Make client follow redirects.
    # @param opts
    # @return [HTTP::Client]
    # @see Redirector#initialize
    def follow(opts = true)
      branch default_options.with_follow opts
    end

    # @deprecated
    # @see #follow
    alias_method :with_follow, :follow

    def with_cache(cache)
      branch default_options.with_cache(cache)
    end

    # Make a request with the given headers
    # @param headers
    def with_headers(headers)
      branch default_options.with_headers(headers)
    end
    alias_method :with, :with_headers

    # Accept the given MIME type(s)
    # @param type
    def accept(type)
      with :accept => MimeType.normalize(type)
    end

    # Make a request with the given Authorization header
    # @param [#to_s] value Authorization header value
    def auth(value, opts = nil)
      # shim for deprecated auth(:basic, opts).
      # will be removed in 0.8.0
      return basic_auth(opts) if :basic == value
      with :authorization => value.to_s
    end

    # Make a request with the given Basic authorization header
    # @see http://tools.ietf.org/html/rfc2617
    # @param [#fetch] opts
    # @option opts [#to_s] :user
    # @option opts [#to_s] :pass
    def basic_auth(opts)
      user = opts.fetch :user
      pass = opts.fetch :pass

      auth("Basic " << Base64.strict_encode64("#{user}:#{pass}"))
    end

    # Get options for HTTP
    # @return [HTTP::Options]
    def default_options
      @default_options ||= HTTP::Options.new
    end

    # Set options for HTTP
    # @param opts
    # @return [HTTP::Options]
    def default_options=(opts)
      @default_options = HTTP::Options.new(opts)
    end

    # Get headers of HTTP options
    def default_headers
      default_options.headers
    end

    # Set headers of HTTP options
    # @param headers
    def default_headers=(headers)
      @default_options = default_options.dup do |opts|
        opts.headers = headers
      end
    end

    private

    # :nodoc:
    def branch(options)
      HTTP::Client.new(options)
    end
  end
end
