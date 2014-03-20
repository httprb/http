require 'http/options'
require 'http/redirector'
require 'uri'

module HTTP
  # Clients make requests and receive responses
  class Client
    include Chainable

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
      headers = opts.headers
      proxy = opts.proxy

      request_body = make_request_body(opts, headers)
      uri, opts = normalize_get_params(uri, opts) if verb == :get

      uri = "#{uri}?#{URI.encode_www_form(opts.params)}" if opts.params && !opts.params.empty?

      request = HTTP::Request.new(verb, uri, headers, proxy, request_body)
      perform request, opts
    end

    # Perform the HTTP request (following redirects if needed)
    def perform(req, options)
      res = perform_without_following_redirects req, options

      if options.follow
        res = Redirector.new(options.follow).perform req, res do |request|
          # TODO: keep-alive
          @parser.reset
          finish_response

          perform_without_following_redirects request, options
        end
      end

      @body_remaining = Integer(res['Content-Length']) if res['Content-Length']
      res
    end

    # Read a chunk of the body
    def readpartial(size = BUFFER_SIZE) # rubocop:disable CyclomaticComplexity
      if @parser.finished? || (@body_remaining && @body_remaining.zero?)
        chunk = @parser.chunk

        if !chunk && @body_remaining && !@body_remaining.zero?
          fail StateError, "expected #{@body_remaining} more bytes of body"
        end

        @body_remaining -= chunk.bytesize if chunk
        return chunk
      end

      fail StateError, 'not connected' unless @socket

      chunk = @parser.chunk
      unless chunk
        begin
          @parser << @socket.readpartial(BUFFER_SIZE)
          chunk = @parser.chunk
        rescue EOFError
          chunk = nil
        end

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

    # Perform a single (no follow) HTTP request
    def perform_without_following_redirects(req, options)
      uri = req.uri

      # TODO: keep-alive support
      @socket = options[:socket_class].open(req.socket_host, req.socket_port)
      @socket = start_tls(@socket, options) if uri.is_a?(URI::HTTPS)

      req.stream @socket

      begin
        @parser << @socket.readpartial(BUFFER_SIZE) until @parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      body = Response::Body.new(self)
      Response.new(@parser.status_code, @parser.http_version, @parser.headers, body, uri)
    end

    # Initialize TLS connection
    def start_tls(socket, options)
      # TODO: abstract away SSLContexts so we can use other TLS libraries
      context = options[:ssl_context] || OpenSSL::SSL::SSLContext.new
      socket  = options[:ssl_socket_class].new(socket, context)

      socket.connect
      socket
    end

    # Create the request body object to send
    def make_request_body(opts, headers)
      if opts.body
        opts.body
      elsif opts.form
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
        URI.encode_www_form(opts.form)
      elsif opts.json
        headers['Content-Type'] ||= 'application/json'
        MimeType[:json].encode opts.json
      end
    end

    # Callback for when we've reached the end of a response
    def finish_response
      # TODO: keep-alive support
      @socket = nil
    end

    # Moves uri get params into the opts.params hash
    # @return [Array<URI, Hash>]
    def normalize_get_params(uri, opts)
      uri = URI(uri) unless uri.is_a?(URI)
      if uri.query
        extracted_params_from_uri = Hash[URI.decode_www_form(uri.query)]
        opts = opts.with_params(extracted_params_from_uri.merge(opts.params || {}))
        uri.query = nil
      end
      [uri, opts]
    end
  end
end
