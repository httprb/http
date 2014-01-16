require 'http/options'
require 'uri'

module HTTP
  # Clients make requests and receive responses
  class Client
    include Chainable

    BUFFER_SIZE = 16384 # Input buffer size

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
    end

    def body(opts, headers)
      if opts.body
        opts.body
      elsif opts.form
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
        URI.encode_www_form(opts.form)
      end
    end

    # Make an HTTP request
    def request(verb, uri, options = {})
      opts = @default_options.merge(options)
      host = URI.parse(uri).host
      scheme = URI.parse(uri).scheme
      opts.headers['Host'] = host
      headers = opts.headers
      proxy = opts.proxy

      method_body = body(opts, headers)
      uri = "#{uri}?#{URI.encode_www_form(opts.params)}" if opts.params

      request = HTTP::Request.new(verb, uri, headers, proxy, method_body)
      if opts.follow
        code = 302
        while code == 302 || code == 301
          # if the uri isn't fully formed complete it
          uri = URI.parse(uri.to_s)
          uri.scheme ||= scheme
          uri.host   ||= host
          opts.headers['Host'] = uri.host
          method_body = body(opts, headers)
          request = HTTP::Request.new(verb, uri, headers, proxy, method_body)
          response = perform request, opts
          code = response.code
          uri = response.headers['Location']
        end
      end

      opts.callbacks[:request].each { |c| c.call(request) }
      response = perform request, opts
      opts.callbacks[:response].each { |c| c.call(response) }

      format_response verb, response, opts.response
    end

    def perform(request, options)
      parser = HTTP::Response::Parser.new
      uri = request.uri
      socket = options[:socket_class].open(uri.host, uri.port) # TODO: proxy support

      if uri.is_a?(URI::HTTPS)
        if options[:ssl_context].nil?
          context = OpenSSL::SSL::SSLContext.new
        else
          context = options[:ssl_context]
        end
        socket = options[:ssl_socket_class].new(socket, context)
        socket.connect
      end

      request.stream socket

      begin
        parser << socket.readpartial(BUFFER_SIZE) until parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      response = HTTP::Response.new(parser.status_code, parser.http_version, parser.headers) do
        if !parser.finished? || (@body_remaining && @body_remaining > 0)
          chunk = parser.chunk || begin
            parser << socket.readpartial(BUFFER_SIZE)
            parser.chunk
          end

          @body_remaining -= chunk.length if @body_remaining
          @body_remaining = nil if @body_remaining && @body_remaining < 1

          chunk
        end
      end

      @body_remaining = Integer(response['Content-Length']) if response['Content-Length']
      response
    end

    def format_response(verb, response, option)
      case option
      when :auto, NilClass
        if verb == :head
          response
        else
          HTTP::Response::BodyDelegator.new(response, response.parse_body)
        end
      when :object
        response
      when :parsed_body
        HTTP::Response::BodyDelegator.new(response, response.parse_body)
      when :body
        HTTP::Response::BodyDelegator.new(response)
      else
        fail(ArgumentError, "invalid response type: #{option}")
      end
    end
  end
end
