require "base64"

require "http/headers"

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

    # @overload(options = {})
    #   Syntax sugar for `timeout(:per_operation, options)`
    # @overload(klass, options = {})
    #   @param [#to_sym] klass
    #   @param [Hash] options
    #   @option options [Float] :read Read timeout
    #   @option options [Float] :write Write timeout
    #   @option options [Float] :connect Connect timeout
    def timeout(klass, options = {})
      klass, options = :per_operation, klass if klass.is_a? Hash

      klass = case klass.to_sym
              when :null          then HTTP::Timeout::Null
              when :global        then HTTP::Timeout::Global
              when :per_operation then HTTP::Timeout::PerOperation
              else fail ArgumentError, "Unsupported Timeout class: #{klass}"
              end

      [:read, :write, :connect].each do |k|
        next unless options.key? k
        options["#{k}_timeout".to_sym] = options.delete k
      end

      branch default_options.merge(
        :timeout_class => klass,
        :timeout_options => options
      )
    end

    # @overload persistent(host)
    #   Flags as persistent
    #   @param [String] host
    #   @raise [Request::Error] if Host is invalid
    #   @return [HTTP::Client] Persistent client
    # @overload persistent(host, &block)
    #   Executes given block with persistent client and automatically closes
    #   connection at the end of execution.
    #
    #   @example
    #
    #       def keys(users)
    #         HTTP.persistent("https://github.com") do |http|
    #           users.map { |u| http.get("/#{u}.keys").to_s }
    #         end
    #       end
    #
    #       # same as
    #
    #       def keys(users)
    #         http = HTTP.persistent "https://github.com"
    #         users.map { |u| http.get("/#{u}.keys").to_s }
    #       ensure
    #         http.close if http
    #       end
    #
    #
    #   @yieldparam [HTTP::Client] client Persistent client
    #   @return [Object] result of last expression in the block
    def persistent(host)
      p_client = branch default_options.with_persistent host
      return p_client unless block_given?
      yield p_client
    ensure
      p_client.close
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

    # Make client follow redirects.
    # @param opts
    # @return [HTTP::Client]
    # @see Redirector#initialize
    def follow(opts = {})
      branch default_options.with_follow opts
    end

    # @deprecated will be removed in 1.0.0
    # @see #follow
    alias_method :with_follow, :follow

    # Make a request with the given headers
    # @param headers
    def headers(headers)
      branch default_options.with_headers(headers)
    end

    # @deprecated will be removed in 1.0.0
    # @see #headers
    alias_method :with, :headers

    # @deprecated will be removed in 1.0.0
    # @see #headers
    alias_method :with_headers, :headers

    # Make a request with the given cookies
    def cookies(cookies)
      branch default_options.with_cookies(cookies)
    end

    # Accept the given MIME type(s)
    # @param type
    def accept(type)
      headers Headers::ACCEPT => MimeType.normalize(type)
    end

    # Make a request with the given Authorization header
    # @param [#to_s] value Authorization header value
    def auth(value, opts = nil)
      # shim for deprecated auth(:basic, opts).
      # will be removed in 0.8.0
      return basic_auth(opts) if :basic == value
      headers Headers::AUTHORIZATION => value.to_s
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

    # @deprecated Will be removed in 1.0.0; Use `#default_options#headers`
    # Get headers of HTTP options
    def default_headers
      default_options.headers
    end

    # Set headers of HTTP options
    # @deprecated Will be removed in 1.0.0; Use `#headers`
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
