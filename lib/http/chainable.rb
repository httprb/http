module Http
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
      unless [:request, :response].include?(event)
        raise ArgumentError, "only :request and :response are valid events"
      end
      unless block_given?
        raise ArgumentError, "no block specified for #{event} event"
      end
      unless block.arity == 1
        raise ArgumentError, "block must accept only one argument"
      end
      branch default_options.with_callback(event, block)
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
        mime_type = Http::MimeType[type]
        raise ArgumentError, "unknown MIME type: #{type}" unless mime_type
        with :accept => mime_type.type
      end
    end

    def default_options
      @default_options ||= Options.new
    end

    def default_options=(opts)
      @default_options = Options.new(opts)
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
      Client.new(options)
    end

  end
end
