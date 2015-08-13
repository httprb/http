require "forwardable"

require "http/form_data"
require "http/options"
require "http/headers"
require "http/connection"
require "http/redirector"
require "http/uri"

module HTTP
  # Clients make requests and receive responses
  class Client
    extend Forwardable
    include Chainable

    KEEP_ALIVE         = "Keep-Alive".freeze
    CLOSE              = "close".freeze

    HTTP_OR_HTTPS_RE   = %r{^https?://}i

    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
      @connection = nil
      @state = :clean
    end

    # Make an HTTP request
    def request(verb, uri, opts = {})
      opts    = @default_options.merge(opts)
      uri     = make_request_uri(uri, opts)
      headers = make_request_headers(opts)
      body    = make_request_body(opts, headers)
      proxy   = opts.proxy

      req = HTTP::Request.new(verb, uri, headers, proxy, body)
      res = perform req, opts

      return res unless opts.follow

      Redirector.new(opts.follow).perform req, res do |request|
        perform request, opts
      end
    end

    # @!method persistent?
    #   @see Options#persistent?
    #   @return [Boolean] whenever client is persistent
    def_delegator :default_options, :persistent?

    # Perform a single (no follow) HTTP request
    def perform(req, options)
      verify_connection!(req.uri)

      @state = :dirty

      @connection ||= HTTP::Connection.new(req, options)

      unless @connection.failed_proxy_connect?
        @connection.send_request(req)
        @connection.read_headers!
      end

      res = Response.new(
        @connection.status_code,
        @connection.http_version,
        @connection.headers,
        Response::Body.new(@connection),
        req.uri
      )

      @connection.finish_response if req.verb == :head
      @state = :clean

      res
    rescue
      # On any exception we reset the conn. This is a safety measure, to ensure
      # we don't have conns in a bad state resulting in mixed requests/responses
      close if persistent?
      raise
    end

    def close
      @connection.close if @connection
      @connection = nil
      @state = :clean
    end

    private

    # Verify our request isn't going to be made against another URI
    def verify_connection!(uri)
      if default_options.persistent? && uri.origin != default_options.persistent
        fail StateError, "Persistence is enabled for #{default_options.persistent}, but we got #{uri.origin}"
      # We re-create the connection object because we want to let prior requests
      # lazily load the body as long as possible, and this mimics prior functionality.
      elsif @connection && (!@connection.keep_alive? || @connection.expired?)
        close
      # If we get into a bad state (eg, Timeout.timeout ensure being killed)
      # close the connection to prevent potential for mixed responses.
      elsif @state == :dirty
        close
      end
    end

    # Merges query params if needed
    #
    # @param [#to_s] uri
    # @return [URI]
    def make_request_uri(uri, opts)
      uri = uri.to_s

      if default_options.persistent? && uri !~ HTTP_OR_HTTPS_RE
        uri = "#{default_options.persistent}#{uri}"
      end

      uri = HTTP::URI.parse uri

      if opts.params && !opts.params.empty?
        uri.query = [uri.query, HTTP::URI.form_encode(opts.params)].compact.join("&")
      end

      # Some proxies (seen on WEBRick) fail if URL has
      # empty path (e.g. `http://example.com`) while it's RFC-complaint:
      # http://tools.ietf.org/html/rfc1738#section-3.1
      uri.path = "/" if uri.path.empty?

      uri
    end

    # Creates request headers with cookies (if any) merged in
    def make_request_headers(opts)
      headers = opts.headers

      # Tell the server to keep the conn open
      if default_options.persistent?
        headers[Headers::CONNECTION] = KEEP_ALIVE
      else
        headers[Headers::CONNECTION] = CLOSE
      end

      cookies = opts.cookies.values
      unless cookies.empty?
        cookies = opts.headers.get(Headers::COOKIE).concat(cookies).join("; ")
        headers[Headers::COOKIE] = cookies
      end

      headers
    end

    # Create the request body object to send
    def make_request_body(opts, headers)
      case
      when opts.body
        opts.body
      when opts.form
        form = HTTP::FormData.create opts.form
        headers[Headers::CONTENT_TYPE]   ||= form.content_type
        headers[Headers::CONTENT_LENGTH] ||= form.content_length
        form.to_s
      when opts.json
        headers[Headers::CONTENT_TYPE] ||= "application/json"
        MimeType[:json].encode opts.json
      end
    end
  end
end
