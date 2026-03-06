# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::AutoInflate do
  let(:feature)    { HTTP::Features::AutoInflate.new }
  let(:connection) { fake }
  let(:headers)    { {} }

  let(:response) do
    HTTP::Response.new(
      version:    "1.1",
      status:     200,
      headers:    headers,
      connection: connection,
      request:    HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  describe "#wrap_response" do
    let(:result) { feature.wrap_response(response) }

    context "when there is no Content-Encoding header" do
      it "returns original request" do
        assert_same response, result
      end
    end

    context "for identity Content-Encoding header" do
      let(:headers) { { content_encoding: "identity" } }

      it "returns original request" do
        assert_same response, result
      end
    end

    context "for unknown Content-Encoding header" do
      let(:headers) { { content_encoding: "not-supported" } }

      it "returns original request" do
        assert_same response, result
      end
    end

    context "for deflate Content-Encoding header" do
      let(:headers) { { content_encoding: "deflate" } }

      it "returns a HTTP::Response wrapping the inflated response body" do
        assert_instance_of HTTP::Response::Body, result.body
      end
    end

    context "for gzip Content-Encoding header" do
      let(:headers) { { content_encoding: "gzip" } }

      it "returns a HTTP::Response wrapping the inflated response body" do
        assert_instance_of HTTP::Response::Body, result.body
      end
    end

    context "for x-gzip Content-Encoding header" do
      let(:headers) { { content_encoding: "x-gzip" } }

      it "returns a HTTP::Response wrapping the inflated response body" do
        assert_instance_of HTTP::Response::Body, result.body
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
end
