require 'http/options'
require 'uri'

module HTTP
  # Clients make requests and receive responses
  class Client
    include Chainable

    # HTTP status codes which indicate redirects
    REDIRECT_CODES = 301..303

    # Input buffer size
    BUFFER_SIZE = 16_384

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
      @parser = HTTP::Response::Parser.new
      @socket = nil
    end

    # Make an HTTP request
    def request(verb, uri, options = {})
      opts = @default_options.merge(options)
      host = URI.parse(uri).host
      scheme = URI.parse(uri).scheme
      opts.headers['Host'] = host
      headers = opts.headers
      proxy = opts.proxy

      request_body = make_request_body(opts, headers)
      uri = "#{uri}?#{URI.encode_www_form(opts.params)}" if opts.params

      request = HTTP::Request.new(verb, uri, headers, proxy, request_body)
      perform request, opts
    end

    # Perform the HTTP request
    def perform(req, options)
      uri = req.uri

      # TODO: proxy support, keep-alive support
      @socket = options[:socket_class].open(uri.host, uri.port) 

      if uri.is_a?(URI::HTTPS)
        if options[:ssl_context].nil?
          context = OpenSSL::SSL::SSLContext.new
        else
          # TODO: abstract away SSLContexts so we can use other SSL libraries
          context = options[:ssl_context]
        end

        @socket = options[:ssl_socket_class].new(socket, context)
        @socket.connect
      end

      req.stream @socket

      begin
        @parser << @socket.readpartial(BUFFER_SIZE) until @parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      body = HTTP::ResponseBody.new(self)
      response = HTTP::Response.new(@parser.status_code, @parser.http_version, @parser.headers, body)

      if options.follow && REDIRECT_CODES.include?(response.code)
        uri = response.headers['Location']
        raise StateError, "no Location header in #{response.code} redirect" unless uri

        # TODO: keep-alive
        @parser.reset
        finish_response
        return request(req.verb, uri, options)
      end

      @body_remaining = Integer(response['Content-Length']) if response['Content-Length']
      response
    end

    # Read a chunk of the body
    def readpartial(size = BUFFER_SIZE)
      if @parser.finished? || (@body_remaining && @body_remaining.zero?)
        chunk = @parser.chunk

        if !chunk && @body_remaining && !@body_remaining.zero?
          raise StateError, "expected #{@body_remaining} more bytes of body"
        end

        @body_remaining -= chunk.bytesize if chunk
        return chunk
      end

      raise StateError, "not connected" unless @socket

      chunk = @parser.chunk
      unless chunk
        @parser << @socket.readpartial(BUFFER_SIZE)
        chunk = @parser.chunk

        # TODO: consult @body_remaining here and raise if appropriate
        return unless chunk
      end

      if @body_remaining
        @body_remaining -= chunk.bytesize
        @body_remaining = nil if @body_remaining < 1
      end

      finish_response if @parser.finished?
      chunk
    end

  private

    # Create the request body object to send
    def make_request_body(opts, headers)
      if opts.body
        opts.body
      elsif opts.form
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
        URI.encode_www_form(opts.form)
      end
    end

    # Callback for when we've reached the end of a response
    def finish_response
      # TODO: keep-alive support
      @socket = nil
    end
  end
end
