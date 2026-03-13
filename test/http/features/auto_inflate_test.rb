# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::AutoInflate do
  cover "HTTP::Features::AutoInflate*"
  let(:feature)    { HTTP::Features::AutoInflate.new }
  let(:connection) { fake }
  let(:headers)    { {} }

  let(:proxy_hdrs) { { "Proxy-Connection" => "keep-alive" } }

  let(:response) do
    HTTP::Response.new(
      version:       "1.1",
      status:        200,
      headers:       headers,
      proxy_headers: proxy_hdrs,
      connection:    connection,
      request:       HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  describe "#wrap_response" do
    let(:result) { feature.wrap_response(response) }

    context "when there is no Content-Encoding header" do
      it "returns original response" do
        assert_same response, result
      end
    end

    context "for identity Content-Encoding header" do
      let(:headers) { { content_encoding: "identity" } }

      it "returns original response" do
        assert_same response, result
      end
    end

    context "for unknown Content-Encoding header" do
      let(:headers) { { content_encoding: "not-supported" } }

      it "returns original response" do
        assert_same response, result
      end
    end

    context "for deflate Content-Encoding header" do
      let(:headers) { { content_encoding: "deflate" } }

      it "returns a new response (not the original)" do
        refute_same response, result
      end

      it "returns an HTTP::Response" do
        assert_instance_of HTTP::Response, result
      end

      it "wraps the body with an inflating body" do
        assert_instance_of HTTP::Response::Body, result.body
      end

      it "preserves the status" do
        assert_equal response.status.code, result.status.code
      end

      it "preserves the version" do
        assert_equal response.version, result.version
      end

      it "preserves the headers" do
        assert_equal response.headers.to_h, result.headers.to_h
      end

      it "preserves the proxy_headers" do
        assert_equal response.proxy_headers.to_h, result.proxy_headers.to_h
        refute_empty result.proxy_headers.to_h
      end

      it "preserves the request" do
        assert_equal response.request, result.request
      end

      it "wraps body stream in an Inflater" do
        stream = result.body.instance_variable_get(:@stream)

        assert_instance_of HTTP::Response::Inflater, stream
      end

      it "passes the original connection to the Inflater" do
        stream = result.body.instance_variable_get(:@stream)

        assert_same connection, stream.connection
      end

      it "preserves the connection on the wrapped response" do
        assert_same connection, result.connection
      end
    end

    context "for gzip Content-Encoding header" do
      let(:headers) { { content_encoding: "gzip" } }

      it "returns a new response wrapping the inflated response body" do
        refute_same response, result
        assert_instance_of HTTP::Response::Body, result.body
      end
    end

    context "for x-gzip Content-Encoding header" do
      let(:headers) { { content_encoding: "x-gzip" } }

      it "returns a new response wrapping the inflated response body" do
        refute_same response, result
        assert_instance_of HTTP::Response::Body, result.body
      end
    end

    context "for gzip Content-Encoding with charset" do
      let(:headers) { { content_encoding: "gzip", content_type: "text/html; charset=Shift_JIS" } }

      it "preserves the encoding from the original response" do
        assert_equal Encoding::Shift_JIS, result.body.encoding
      end
    end

    context "when response has uri" do
      let(:response) do
        HTTP::Response.new(
          version:    "1.1",
          status:     200,
          headers:    { content_encoding: "gzip" },
          connection: connection,
          request:    HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "preserves uri in wrapped response" do
        assert_equal HTTP::URI.parse("https://example.com"), result.uri
      end
    end
  end

  describe "#stream_for" do
    it "returns an HTTP::Response::Body" do
      result = feature.stream_for(connection)

      assert_instance_of HTTP::Response::Body, result
    end

    it "defaults to BINARY encoding" do
      result = feature.stream_for(connection)

      assert_equal Encoding::BINARY, result.encoding
    end

    it "uses the given encoding" do
      result = feature.stream_for(connection, encoding: Encoding::UTF_8)

      assert_equal Encoding::UTF_8, result.encoding
    end

    it "wraps the connection in an Inflater" do
      result = feature.stream_for(connection)
      stream = result.instance_variable_get(:@stream)

      assert_instance_of HTTP::Response::Inflater, stream
    end

    it "passes the connection to the Inflater" do
      result = feature.stream_for(connection)
      stream = result.instance_variable_get(:@stream)

      assert_same connection, stream.connection
    end
  end
end
