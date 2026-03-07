# frozen_string_literal: true

module HTTP
  class Client
    # Private methods for building request components
    module RequestBuilder
      private

      # Merges query params if needed
      #
      # @param uri [#to_s] the URI to process
      # @param opts [HTTP::Options] request options
      # @return [HTTP::URI] the constructed URI
      # @api private
      def make_request_uri(uri, opts)
        uri = uri.to_s

        uri = "#{default_options.persistent}#{uri}" if default_options.persistent? && uri !~ HTTP_OR_HTTPS_RE

        uri = HTTP::URI.parse uri

        merge_query_params!(uri, opts)

        # Some proxies (seen on WEBRick) fail if URL has
        # empty path (e.g. `http://example.com`) while it's RFC-complaint:
        # http://tools.ietf.org/html/rfc1738#section-3.1
        uri.path = "/" if uri.path.empty?

        uri
      end

      # Merge query parameters into URI
      #
      # @return [void]
      # @api private
      def merge_query_params!(uri, opts)
        return unless opts.params && !opts.params.empty?

        uri.query_values = uri.query_values(Array).to_a.concat(opts.params.to_a)
      end

      # Creates request headers with cookies (if any) merged in
      #
      # @return [HTTP::Headers] the constructed headers
      # @api private
      def make_request_headers(opts)
        headers = opts.headers

        # Tell the server to keep the conn open
        headers[Headers::CONNECTION] = default_options.persistent? ? Connection::KEEP_ALIVE : Connection::CLOSE

        cookies = opts.cookies.values

        unless cookies.empty?
          cookies = opts.headers.get(Headers::COOKIE).concat(cookies).join("; ")
          headers[Headers::COOKIE] = cookies
        end

        headers
      end

      # Create the request body object to send
      #
      # @return [String, HTTP::FormData, nil] the request body
      # @api private
      def make_request_body(opts, headers)
        if opts.body
          opts.body
        elsif opts.form
          form = make_form_data(opts.form)
          headers[Headers::CONTENT_TYPE] ||= form.content_type
          form
        elsif opts.json
          make_json_body(opts.json, headers)
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
