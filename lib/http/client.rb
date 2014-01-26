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
      @socket = nil
    end

    # Make an HTTP request
    def request(verb, uri, options = {})
      opts = @default_options.merge(options)
      host = URI.parse(uri).host
      opts.headers['Host'] = host
      headers = opts.headers
      proxy = opts.proxy

      request_body = make_request_body(opts, headers)
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
          finish_response
          perform_without_following_redirects request, options
        end
      end

      @body_remaining = Integer(res['Content-Length']) if res['Content-Length']
      res
    end

  private

    # Perform a single (no follow) HTTP request
    def perform_without_following_redirects(req, options)
      uri = req.uri

      # TODO: keep-alive support
      @socket = options[:socket_class].open(req.socket_host, req.socket_port)
      @socket = start_tls(@socket, options) if uri.is_a?(URI::HTTPS)
      connection = HTTP::Connection.new(@socket)
      parser     = HTTP::Parser.new(connection)

      req.stream @socket

      begin
        parser << @socket.readpartial(BUFFER_SIZE) until parser.headers
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE => ex
        raise IOError, "problem making HTTP request: #{ex}"
      end

      HTTP::Response.new(connection, parser.status_code, parser.http_version, parser.headers, uri)
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
      end
    end

    # Callback for when we've reached the end of a response
    def finish_response
      # TODO: keep-alive support
      @socket = nil
    end
  end
end
