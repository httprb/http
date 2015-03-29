require "cgi"
require "uri"

require "http/form_data"
require "http/options"
require "http/connection"
require "http/redirector"
require "http/uri"

module HTTP
  # Clients make requests and receive responses
  class Client
    include Chainable

    CONNECTION         = "Connection".freeze
    KEEP_ALIVE         = "Keep-Alive".freeze
    CLOSE              = "close".freeze

    HTTP_OR_HTTPS_RE   = %r{^https?://}i

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = HTTP::Options.new(default_options)
      @connection = nil
      @state = :clean
    end

    # Make an HTTP request
    def request(verb, uri, opts = {})
      opts    = @default_options.merge(opts)
      uri     = make_request_uri(uri, opts)
      headers = opts.headers
      proxy   = opts.proxy
      body    = make_request_body(opts, headers)

      # Tell the server to keep the conn open
      if default_options.persistent?
        headers[CONNECTION] = KEEP_ALIVE
      else
        headers[CONNECTION] = CLOSE
      end

      req = HTTP::Request.new(verb, uri, headers, proxy, body)
      res = perform req, opts

      return res unless opts.follow

      Redirector.new(opts.follow).perform req, res do |request|
        perform request, opts
      end
    end

    # Perform a single (no follow) HTTP request
    def perform(req, options)
      options.cache.perform(req, options) do |r, opts|
        make_request(r, opts)
      end
    end

    def make_request(req, options)
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

    # On any exception we reset the conn. This is a safety measure, to ensure
    # we don't have conns in a bad state resulting in mixed requests/responses
    rescue
      close if default_options.persistent?

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
      if default_options.persistent? && base_host(uri) != default_options.persistent
        fail StateError, "Persistence is enabled for #{default_options.persistent}, but we got #{base_host(uri)}"
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

    # Strips out query/path to give us a consistent way of comparing hosts
    def base_host(uri)
      uri.omit(:query, :path).to_s
    end

    # Merges query params if needed
    #
    # @param [#to_s] uri
    # @return [URI]
    def make_request_uri(uri, options)
      uri = uri.to_s

      if default_options.persistent? && uri !~ HTTP_OR_HTTPS_RE
        uri = "#{default_options.persistent}#{uri}"
      end

      uri = HTTP::URI.parse uri

      if options.params && !options.params.empty?
        params    = CGI.parse(uri.query.to_s).merge(options.params || {})
        uri.query = ::URI.encode_www_form params
      end

      # Some proxies (seen on WEBRick) fail if URL has
      # empty path (e.g. `http://example.com`) while it's RFC-complaint:
      # http://tools.ietf.org/html/rfc1738#section-3.1
      uri.path = "/" if uri.path.empty?

      uri
    end

    # Create the request body object to send
    def make_request_body(opts, headers)
      case
      when opts.body
        opts.body
      when opts.form
        form = HTTP::FormData.create opts.form
        headers["Content-Type"]   ||= form.content_type
        headers["Content-Length"] ||= form.content_length
        form.to_s
      when opts.json
        headers["Content-Type"] ||= "application/json"
        MimeType[:json].encode opts.json
      end
    end
  end
end
