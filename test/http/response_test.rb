# frozen_string_literal: true

require "test_helper"

describe HTTP::Response do
  cover "HTTP::Response*"
  let(:response) do
    HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: headers,
      body:    body,
      request: request
    )
  end

  let(:body)          { "Hello world!" }
  let(:uri)           { "http://example.com/" }
  let(:headers)       { {} }
  let(:request)       { HTTP::Request.new(verb: :get, uri: uri) }

  it "provides a #headers accessor" do
    assert_kind_of HTTP::Headers, response.headers
  end

  describe "to_a" do
    let(:body)         { "Hello world" }
    let(:content_type) { "text/plain" }
    let(:headers)      { { "Content-Type" => content_type } }

    it "returns a Rack-like array" do
      assert_equal [200, headers, body], response.to_a
    end

    it "returns an Integer status code" do
      assert_instance_of Integer, response.to_a.fetch(0)
    end

    it "returns a plain Hash for headers" do
      result = response.to_a.fetch(1)

      assert_instance_of Hash, result
      refute_instance_of HTTP::Headers, result
    end

    it "returns a String for body" do
      conn = fake(sequence_id: 0, readpartial: proc { raise EOFError }, body_completed?: true)
      resp = HTTP::Response.new(status: 200, version: "1.1", headers: headers,
                                connection: conn, request: request)
      result = resp.to_a.fetch(2)

      assert_instance_of String, result
      refute_instance_of HTTP::Response::Body, result
    end
  end

  describe "#deconstruct_keys" do
    it "returns all keys when given nil" do
      result = response.deconstruct_keys(nil)

      assert_instance_of HTTP::Response::Status, result[:status]
      assert_equal "1.1", result[:version]
      assert_instance_of HTTP::Headers, result[:headers]
      assert_equal body, result[:body]
      assert_equal request, result[:request]
      assert_instance_of HTTP::Headers, result[:proxy_headers]
    end

    it "returns only requested keys" do
      result = response.deconstruct_keys(%i[status version])

      assert_equal 2, result.size
      assert_instance_of HTTP::Response::Status, result[:status]
      assert_equal "1.1", result[:version]
    end

    it "excludes unrequested keys" do
      result = response.deconstruct_keys([:status])

      refute_includes result.keys, :version
      refute_includes result.keys, :body
    end

    it "returns empty hash for empty keys" do
      assert_equal({}, response.deconstruct_keys([]))
    end

    it "supports hash pattern matching" do
      matched = case response
                in { status: HTTP::Response::Status, version: "1.1" }
                  true
                else
                  false
                end

      assert matched
    end
  end

  describe "#deconstruct" do
    let(:body)         { "Hello world" }
    let(:content_type) { "text/plain" }
    let(:headers)      { { "Content-Type" => content_type } }

    it "returns a Rack-like array" do
      assert_equal [200, headers, body], response.deconstruct
    end

    it "supports array pattern matching" do
      matched = case response
                in [200, *, String]
                  true
                else
                  false
                end

      assert matched
    end
  end

  describe "#content_length" do
    context "without Content-Length header" do
      it "returns nil" do
        assert_nil response.content_length
      end
    end

    context "with Content-Length: 5" do
      let(:headers) { { "Content-Length" => "5" } }

      it "returns 5" do
        assert_equal 5, response.content_length
      end
    end

    context "with invalid Content-Length" do
      let(:headers) { { "Content-Length" => "foo" } }

      it "returns nil" do
        assert_nil response.content_length
      end
    end

    context "with duplicate identical Content-Length" do
      let(:headers) do
        h = HTTP::Headers.new
        h.add("Content-Length", "5")
        h.add("Content-Length", "5")
        h
      end

      it "returns the deduplicated value" do
        assert_equal 5, response.content_length
      end
    end

    context "with conflicting Content-Length values" do
      let(:headers) do
        h = HTTP::Headers.new
        h.add("Content-Length", "5")
        h.add("Content-Length", "10")
        h
      end

      it "returns nil" do
        assert_nil response.content_length
      end
    end

    context "with Transfer-Encoding header" do
      let(:headers) { { "Transfer-Encoding" => "chunked", "Content-Length" => "5" } }

      it "returns nil" do
        assert_nil response.content_length
      end
    end
  end

  describe "mime_type" do
    context "without Content-Type header" do
      let(:headers) { {} }

      it "returns nil" do
        assert_nil response.mime_type
      end
    end

    context "with Content-Type: text/html" do
      let(:headers) { { "Content-Type" => "text/html" } }

      it "returns text/html" do
        assert_equal "text/html", response.mime_type
      end
    end

    context "with Content-Type: text/html; charset=utf-8" do
      let(:headers) { { "Content-Type" => "text/html; charset=utf-8" } }

      it "returns text/html" do
        assert_equal "text/html", response.mime_type
      end
    end
  end

  describe "charset" do
    context "without Content-Type header" do
      let(:headers) { {} }

      it "returns nil" do
        assert_nil response.charset
      end
    end

    context "with Content-Type: text/html" do
      let(:headers) { { "Content-Type" => "text/html" } }

      it "returns nil" do
        assert_nil response.charset
      end
    end

    context "with Content-Type: text/html; charset=utf-8" do
      let(:headers) { { "Content-Type" => "text/html; charset=utf-8" } }

      it "returns utf-8" do
        assert_equal "utf-8", response.charset
      end
    end
  end

  describe "#parse" do
    let(:headers)   { { "Content-Type" => content_type } }
    let(:body)      { '{"foo":"100%s"}' }

    context "with known content type" do
      let(:content_type) { "application/json" }

      it "returns parsed body" do
        assert_equal({ "foo" => "100%s" }, response.parse)
      end
    end

    context "with unknown content type" do
      let(:content_type) { "application/deadbeef" }

      it "raises HTTP::ParseError" do
        assert_raises(HTTP::ParseError) { response.parse }
      end
    end

    context "with explicitly given mime type" do
      let(:content_type) { "application/deadbeef" }

      it "ignores mime_type of response" do
        assert_equal({ "foo" => "100%s" }, response.parse("application/json"))
      end

      it "supports mime type aliases" do
        assert_equal({ "foo" => "100%s" }, response.parse(:json))
      end
    end

    context "when underlying parser fails" do
      let(:content_type) { "application/deadbeef" }
      let(:body)         { "" }

      it "raises HTTP::ParseError" do
        assert_raises(HTTP::ParseError) { response.parse }
      end

      it "preserves the original error message" do
        err = assert_raises(HTTP::ParseError) { response.parse }

        assert_includes err.message, "application/deadbeef"
      end
    end
  end

  describe "#flush" do
    it "returns response self-reference" do
      mock_body = fake(to_s: "")
      resp = HTTP::Response.new(status: 200, version: "1.1", body: mock_body, request: request)

      assert_same resp, resp.flush
    end

    it "flushes body" do
      to_s_called = false
      mock_body = Object.new
      mock_body.define_singleton_method(:to_s) do
        to_s_called = true
        ""
      end
      resp = HTTP::Response.new(status: 200, version: "1.1", body: mock_body, request: request)
      resp.flush

      assert to_s_called, "expected body.to_s to be called"
    end
  end

  describe "#inspect" do
    let(:headers) { { content_type: "text/plain" } }
    let(:body)    { fake(to_s: "foobar") }

    it "returns a useful string representation" do
      assert_equal "#<HTTP::Response/1.1 200 OK text/plain>", response.inspect
    end
  end

  describe "#cookies" do
    let(:cookie_list) { response.cookies }

    let(:cookies) { ["a=1", "b=2; domain=example.com", "c=3; domain=bad.org"] }
    let(:headers) { { "Set-Cookie" => cookies } }

    it "returns an Array of HTTP::Cookie" do
      assert_kind_of Array, cookie_list
      cookie_list.each { |c| assert_kind_of HTTP::Cookie, c }
    end

    it "contains cookies without domain restriction" do
      assert_equal(1, cookie_list.count { |c| "a" == c.name })
    end

    it "contains cookies limited to domain of request uri" do
      assert_equal(1, cookie_list.count { |c| "b" == c.name })
    end

    it "does not contain cookies limited to non-requested uri" do
      assert_equal(0, cookie_list.count { |c| "c" == c.name })
    end
  end

  describe "#connection" do
    let(:response) do
      HTTP::Response.new(
        version:    "1.1",
        status:     200,
        connection: connection,
        request:    request
      )
    end

    let(:connection) { fake }

    it "returns the connection object used to instantiate the response" do
      assert_equal connection, response.connection
    end
  end

  describe "#chunked?" do
    context "when encoding is set to chunked" do
      let(:headers) { { "Transfer-Encoding" => "chunked" } }

      it "returns true" do
        assert_predicate response, :chunked?
      end
    end

    it "returns false by default" do
      refute_predicate response, :chunked?
    end
  end

  describe "backwards compatibility with :uri" do
    context "with no :verb" do
      let(:response) do
        HTTP::Response.new(
          status:  200,
          version: "1.1",
          headers: headers,
          body:    body,
          uri:     uri
        )
      end

      it "defaults the uri to :uri" do
        assert_equal uri, response.request.uri.to_s
      end

      it "defaults to the verb to :get" do
        assert_equal :get, response.request.verb
      end
    end

    context "with both a :request and :uri" do
      it "raises ArgumentError with a descriptive message" do
        err = assert_raises(ArgumentError) do
          HTTP::Response.new(
            status:  200,
            version: "1.1",
            headers: headers,
            body:    body,
            uri:     uri,
            request: request
          )
        end

        assert_includes err.message, ":uri"
      end
    end
  end

  describe "#body" do
    let(:response) do
      HTTP::Response.new(
        status:     200,
        version:    "1.1",
        headers:    headers,
        request:    request,
        connection: connection
      )
    end

    let(:connection) do
      fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
        chunks.empty?
      })
    end
    let(:chunks)     { ["Hello, ", "World!"] }

    context "with no Content-Type" do
      let(:headers) { {} }

      it "returns a body with default binary encoding" do
        assert_equal Encoding::BINARY, response.body.to_s.encoding
      end
    end

    context "with Content-Type: application/json" do
      let(:headers) { { "Content-Type" => "application/json" } }

      it "returns a body with a default UTF_8 encoding" do
        assert_equal Encoding::UTF_8, response.body.to_s.encoding
      end
    end

    context "with Content-Type: text/html (non-JSON)" do
      let(:headers) { { "Content-Type" => "text/html" } }

      it "returns a body with default binary encoding" do
        assert_equal Encoding::BINARY, response.body.to_s.encoding
      end
    end

    context "with Content-Type: text/html; charset=utf-8" do
      let(:headers) { { "Content-Type" => "text/html; charset=utf-8" } }

      it "uses charset for body encoding" do
        assert_equal Encoding::UTF_8, response.body.to_s.encoding
      end
    end

    context "with explicit encoding" do
      let(:headers) { {} }

      it "passes encoding to the body" do
        conn = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) },
                    body_completed?: proc { chunks.empty? })
        resp = HTTP::Response.new(
          status: 200, version: "1.1", headers: headers,
          request: request, connection: conn, encoding: "UTF-8"
        )

        assert_equal Encoding::UTF_8, resp.body.to_s.encoding
      end
    end
  end

  describe "#initialize defaults" do
    it "defaults headers to empty" do
      resp = HTTP::Response.new(status: 200, version: "1.1", body: "ok", request: request)

      assert_empty resp.headers
    end

    it "defaults proxy_headers to empty" do
      resp = HTTP::Response.new(status: 200, version: "1.1", body: "ok", request: request)

      assert_empty resp.proxy_headers
    end

    it "passes proxy_headers through to accessor" do
      resp = HTTP::Response.new(
        status: 200, version: "1.1", body: "ok", request: request,
        proxy_headers: { "Via" => "1.1 proxy" }
      )

      assert_equal "1.1 proxy", resp.proxy_headers["Via"]
    end
  end
end
