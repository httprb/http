# frozen_string_literal: true

require "http/form_data"
require "http/headers"
require "http/connection"
require "http/uri"

module HTTP
  class Request
    # Builds HTTP::Request objects from resolved options
    #
    # @example Build a request from options
    #   options = HTTP::Options.new(headers: {"Accept" => "application/json"})
    #   builder = HTTP::Request::Builder.new(options)
    #   request = builder.build(:get, "https://example.com")
    #
    # @see Options
    class Builder
      # Pattern matching HTTP or HTTPS URI schemes
      HTTP_OR_HTTPS_RE = %r{^https?://}i

      # Initialize a new Request Builder
      #
      # @example
      #   HTTP::Request::Builder.new(HTTP::Options.new)
      #
      # @param options [HTTP::Options] resolved request options
      # @return [HTTP::Request::Builder]
      # @api public
      def initialize(options)
        @options = options
      end

      # Build an HTTP request
      #
      # @example
      #   builder.build(:get, "https://example.com")
      #
      # @param verb [Symbol] the HTTP method
      # @param uri [#to_s] the URI to request
      # @return [HTTP::Request] the built request object
      # @api public
      def build(verb, uri)
        uri     = make_request_uri(uri)
        headers = make_request_headers
        body    = make_request_body(headers)

        req = HTTP::Request.new(
          verb:           verb,
          uri:            uri,
          uri_normalizer: @options.feature(:normalize_uri)&.normalizer,
          proxy:          @options.proxy,
          headers:        headers,
          body:           body
        )

        wrap(req)
      end

      # Wrap a request through feature middleware
      #
      # @example
      #   builder.wrap(redirect_request)
      #
      # @param request [HTTP::Request] the request to wrap
      # @return [HTTP::Request] the wrapped request
      # @api public
      def wrap(request)
        @options.features.inject(request) do |req, (_name, feature)|
          feature.wrap_request(req)
        end
      end

      private

      # Merges query params if needed
      #
      # @param uri [#to_s] the URI to process
      # @return [HTTP::URI] the constructed URI
      # @api private
      def make_request_uri(uri)
        uri = uri.to_s

        uri = "#{@options.persistent}#{uri}" if @options.persistent? && uri !~ HTTP_OR_HTTPS_RE

        uri = HTTP::URI.parse uri

        merge_query_params!(uri)

        # Some proxies (seen on WEBrick) fail if URL has
        # empty path (e.g. `http://example.com`) while it's RFC-compliant:
        # http://tools.ietf.org/html/rfc1738#section-3.1
        uri.path = "/" if uri.path.empty?

        uri
      end

      # Merge query parameters into URI
      #
      # @return [void]
      # @api private
      def merge_query_params!(uri)
        return unless @options.params && !@options.params.empty?

        uri.query_values = uri.query_values(Array).to_a.concat(@options.params.to_a)
      end

      # Creates request headers
      #
      # @return [HTTP::Headers] the constructed headers
      # @api private
      def make_request_headers
        headers = @options.headers

        # Tell the server to keep the conn open
        headers[Headers::CONNECTION] = @options.persistent? ? Connection::KEEP_ALIVE : Connection::CLOSE

        headers
      end

      # Create the request body object to send
      #
      # @return [String, HTTP::FormData, nil] the request body
      # @api private
      def make_request_body(headers)
        if @options.body
          @options.body
        elsif @options.form
          form = make_form_data(@options.form)
          headers[Headers::CONTENT_TYPE] ||= form.content_type
          form
        elsif @options.json
          make_json_body(@options.json, headers)
        end
      end

      # Encode JSON body and set content type header
      # @return [String] the encoded JSON body
      # @api private
      def make_json_body(data, headers)
        body = MimeType[:json].encode data
        headers[Headers::CONTENT_TYPE] ||= "application/json; charset=#{body.encoding.name.downcase}"
        body
      end

      # Coerce form data into an HTTP::FormData object
      # @return [HTTP::FormData::Multipart, HTTP::FormData::Urlencoded] form data
      # @api private
      def make_form_data(form)
        return form if form.is_a? HTTP::FormData::Multipart
        return form if form.is_a? HTTP::FormData::Urlencoded

        HTTP::FormData.create(form)
      end
    end
  end
end
