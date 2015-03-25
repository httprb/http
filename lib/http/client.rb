require 'cgi'
require 'uri'
require 'http/options'
require 'http/redirector'

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
    def request(verb, uri, opts = {})
      opts    = @default_options.merge(opts)
      uri     = make_request_uri(uri, opts)
      headers = opts.headers
      proxy   = opts.proxy
      body    = make_request_body(opts, headers)

      req = HTTP::Request.new(verb, uri, headers, proxy, body)
      res = perform req, opts

      if opts.follow
        res = Redirector.new(opts.follow).perform req, res do |request|
          perform request, opts
        end
      end

      res
    end

    # Perform a single (no follow) HTTP request
    def perform(req, options)
      # finish previous response if client was re-used
      # TODO: this is pretty wrong, as socket shoud be part of response
      #       connection, so that re-use of client will not break multiple
      #       chunked responses
      finish_response

      uri = req.uri

      # TODO: keep-alive support
      @socket = options[:socket_class].open(req.socket_host, req.socket_port)
      @socket = start_tls(@socket, uri.host, options) if uri.is_a?(URI::HTTPS)

      req.stream @socket

      read_headers!

      body = Response::Body.new(self)
      res  = Response.new(@parser.status_code, @parser.http_version, @parser.headers, body, uri)

      finish_response if :head == req.verb

      res
    end

    # Read a chunk of the body
    def readpartial(size = BUFFER_SIZE)
      return unless @socket

      begin
        read_more size
        finished = @parser.finished?
      rescue EOFError
        finished = true
      end

      chunk = @parser.chunk

      finish_response if finished

      chunk.to_s
    end

  private

    # Initialize TLS connection
    def start_tls(socket, host, options)
      # TODO: abstract away SSLContexts so we can use other TLS libraries
      context = options[:ssl_context] || OpenSSL::SSL::SSLContext.new
      socket  = options[:ssl_socket_class].new(socket, context)

      socket.connect

      if context.verify_mode == OpenSSL::SSL::VERIFY_PEER
        socket.post_connection_check(host)
      end

      socket
    end

    # Merges query params if needed
    def make_request_uri(uri, options)
      uri = normalize_uri uri

      if options.params && !options.params.empty?
        params    = CGI.parse(uri.query.to_s).merge(options.params || {})
        uri.query = URI.encode_www_form params
      end

      uri
    end

    # Normalize URI
    #
    # @param [#to_s] uri
    # @return [URI]
    def normalize_uri(uri)
      uri = URI uri.to_s

      # Some proxies (seen on WEBRick) fail if URL has
      # empty path (e.g. `http://example.com`) while it's RFC-complaint:
      # http://tools.ietf.org/html/rfc1738#section-3.1
      uri.path = '/' if uri.path.empty?

      uri
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

    # Reads data from socket up until headers
    def read_headers!
      read_more BUFFER_SIZE until @parser.headers
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
      return if ex.is_a?(EOFError) && @parser.headers
      raise IOError, "problem making HTTP request: #{ex}"
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
    end
  end
end
