require 'uri'

module Http
  # Clients make requests and receive responses
  class Client
    include Chainable

    BUFFER_SIZE = 4096 # Input buffer size

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = Options.new(default_options)
    end

    # Make an HTTP request
    def request(method, uri, options = {})
      opts = @default_options.merge(options)
      headers = opts.headers
      proxy = opts.proxy

      if opts.body
        body = opts.body
      elsif opts.form
        body = URI.encode_www_form(opts.form)
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
      end

      request = Request.new method, uri, headers, proxy, body

      opts.callbacks[:request].each { |c| c.call(request) }
      response = perform request, opts
      opts.callbacks[:response].each { |c| c.call(response) }

      format_response method, response, opts.response
    end

    def perform(request, options)
      parser = Http::Response::Parser.new
      uri, proxy = request.uri, request.proxy
      socket = options[:socket_class].open(uri.host, uri.port) # TODO: proxy support

      if uri.is_a?(URI::HTTPS)
        socket = options[:ssl_socket_class].open(socket, options[:ssl_context])
        socket.connect
      end

      request.stream socket

      begin
        parser << socket.readpartial(BUFFER_SIZE) until parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE
        # TODO: handle errors
        raise 'zomg IO troubles'
      end

      response = Http::Response.new(parser.status_code, parser.http_version, parser.headers) do
        if @body_remaining and @body_remaining > 0
          chunk = parser.chunk
          unless chunk
            parser << socket.readpartial(BUFFER_SIZE)
            chunk = parser.chunk
            return unless chunk
          end

          @body_remaining -= chunk.length
          @body_remaining = nil if @body_remaining < 1

          chunk
        end
      end

      @body_remaining = Integer(response['Content-Length']) if response['Content-Length']
      response
    end

    def format_response(method, response, option)
      case option
      when :auto, NilClass
        method == :head ? response : response.parse_body
      when :object
        response
      when :parsed_body
        response.parse_body
      when :body
        response.body
      else raise ArgumentError, "invalid response type: #{option}"
      end
    end
  end
end
