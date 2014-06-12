require 'http/authorization_header'

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
    # @param [*String] args
    # @raise ArgumentError if the size of arguments is not 1 or 2
    def auth(*args)
      value = case args.count
              when 1 then args.first
              when 2 then AuthorizationHeader.build(*args)
              else fail ArgumentError, "wrong number of arguments (#{args.count} for 1..2)"
              end

      with :authorization => value.to_s
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

    # Get callbacks of HTTP options
    def default_callbacks
      default_options.callbacks
    end

    # Set callbacks of HTTP options
    # @param callbacks
    def default_callbacks=(callbacks)
      @default_options = default_options.dup do |opts|
        opts.callbacks = callbacks
      end
    end

  private

    # :nodoc:
    def branch(options)
      HTTP::Client.new(options)
    end
  end
end
