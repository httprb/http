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
          perform_without_following_redirects request, options
        end
      end

      res
    end

    # Read a chunk of the body
    def readpartial(size = BUFFER_SIZE)
      return unless @socket

      read_more size
      chunk = @parser.chunk

      finish_response if @parser.finished?

      chunk
    end

  private

    # Perform a single (no follow) HTTP request
    def perform_without_following_redirects(req, options)
      # finish previous response if client was re-used
      # TODO: this is pretty wrong, as socket shoud be part of response
      #       connection, so that re-use of client will not break multiple
      #       chunked responses
      finish_response

      uri = req.uri

      # TODO: keep-alive support
      @socket = options[:socket_class].open(req.socket_host, req.socket_port)
      @socket = start_tls(@socket, options) if uri.is_a?(URI::HTTPS)

      req.stream @socket

      begin
        read_more BUFFER_SIZE until @parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      body = Response::Body.new(self)
      res  = Response.new(@parser.status_code, @parser.http_version, @parser.headers, body, uri)

      finish_response if :head == req.verb

      res
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
      @socket.close if @socket && !@socket.closed?
      @parser.reset

      @socket = nil
    end

    # Feeds some more data into parser
    def read_more(size)
      @parser << @socket.readpartial(size) unless @parser.finished?
      return true
    rescue EOFError
      return false
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
