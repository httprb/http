module HTTP
  module Chainable
    # Request a get sans response body
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource
    def patch(uri, options = {})
      request :patch, uri, options
    end

    # Make an HTTP request with the given verb
    def request(verb, uri, options = {})
      branch(options).request verb, uri
    end

    # Make a request invoking the given event callbacks
    def on(event, &block)
      branch default_options.with_callback(event, block)
    end

    # Make a request through an HTTP proxy
    def via(*proxy)
      proxy_hash = {}
      proxy_hash[:proxy_address] = proxy[0] if proxy[0].is_a? String
      proxy_hash[:proxy_port]    = proxy[1] if proxy[1].is_a? Integer
      proxy_hash[:proxy_username]= proxy[2] if proxy[2].is_a? String
      proxy_hash[:proxy_password]= proxy[3] if proxy[3].is_a? String

      if proxy_hash.keys.size >=2
        branch default_options.with_proxy(proxy_hash)
      else
        raise ArgumentError, "invalid HTTP proxy: #{proxy_hash}"
      end
    end
    alias_method :through, :via

    # Specify the kind of response to return (:auto, :object, :body, :parsed_body)
    def with_response(response_type)
      branch default_options.with_response(response_type)
    end

    # Alias for with_response(:object)
    def stream; with_response(:object); end

    def with_follow(follow)
      branch default_options.with_follow(follow)
    end

    # Make a request with the given headers
    def with_headers(headers)
      branch default_options.with_headers(headers)
    end
    alias_method :with, :with_headers

    # Accept the given MIME type(s)
    def accept(type)
      if type.is_a? String
        with :accept => type
      else
        mime_type = HTTP::MimeType[type]
        raise ArgumentError, "unknown MIME type: #{type}" unless mime_type
        with :accept => mime_type.type
      end
    end

    def default_options
      @default_options ||= HTTP::Options.new
    end

    def default_options=(opts)
      @default_options = HTTP::Options.new(opts)
    end

    def default_headers
      default_options.headers
    end

    def default_headers=(headers)
      @default_options = default_options.dup do |opts|
        opts.headers = headers
      end
    end

    def default_callbacks
      default_options.callbacks
    end

    def default_callbacks=(callbacks)
      @default_options = default_options.dup do |opts|
        opts.callbacks = callbacks
      end
    end

    private

    def branch(options)
      HTTP::Client.new(options)
    end
  end
end
