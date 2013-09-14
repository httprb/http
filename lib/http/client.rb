require 'http/options'
require 'uri'

module HTTP
  # Clients make requests and receive responses
  class Client
    include Chainable

    BUFFER_SIZE = 16_384 # Input buffer size

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
      @parser = HTTP::Response::Parser.new
      @socket = nil
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

      perform request, opts
    end

    def perform(request, options)
      uri = request.uri

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

      request.stream @socket

      begin
        @parser << @socket.readpartial(BUFFER_SIZE) until @parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      body = HTTP::ResponseBody.new(self)
      response = HTTP::Response.new(@parser.status_code, @parser.http_version, @parser.headers, body)

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

    # Callback for when we've reached the end of a response
    def finish_response
      # TODO: keep-alive support
      @socket.close if @socket
      @socket = nil
    end
  end
end
