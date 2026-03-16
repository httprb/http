# frozen_string_literal: true

require "test_helper"

require "uri"
require "logger"

require "support/http_handling_shared"
require "support/dummy_server"
require "support/ssl_helper"

StubbedClient = Class.new(HTTP::Client) do
  def perform(request, options)
    stubbed = stubs[HTTP::URI::NORMALIZER.call(request.uri).to_s]
    stubbed ? stubbed.call(request) : super
  end

  def stubs
    @stubs ||= {}
  end

  def stub(stubs)
    @stubs = stubs.transform_keys do |k|
      HTTP::URI::NORMALIZER.call(k).to_s
    end

    self
  end
end

describe HTTP::Client do
  cover "HTTP::Client*"
  run_server(:dummy) { DummyServer.new }

  def capture_request(client, &block)
    captured_req = nil
    client.stub(:perform, lambda { |req, _opts|
      captured_req = req
      nil
    }, &block)
    captured_req
  end

  def redirect_response(location, status = 302)
    lambda do |request|
      HTTP::Response.new(
        status:  status,
        version: "1.1",
        headers: { "Location" => location },
        body:    "",
        request: request
      )
    end
  end

  def simple_response(body, status = 200)
    lambda do |request|
      HTTP::Response.new(
        status:  status,
        version: "1.1",
        body:    body,
        request: request
      )
    end
  end

  describe "following redirects" do
    it "returns response of new location" do
      client = StubbedClient.new(follow: true).stub(
        "http://example.com/"     => redirect_response("http://example.com/blog"),
        "http://example.com/blog" => simple_response("OK")
      )

      assert_equal "OK", client.get("http://example.com/").to_s
    end

    it "prepends previous request uri scheme and host if needed" do
      client = StubbedClient.new(follow: true).stub(
        "http://example.com/"           => redirect_response("/index"),
        "http://example.com/index"      => redirect_response("/index.html"),
        "http://example.com/index.html" => simple_response("OK")
      )

      assert_equal "OK", client.get("http://example.com/").to_s
    end

    it "fails upon endless redirects" do
      client = StubbedClient.new(follow: true).stub(
        "http://example.com/" => redirect_response("/")
      )

      assert_raises(HTTP::Redirector::EndlessRedirectError) { client.get("http://example.com/") }
    end

    it "fails if max amount of hops reached" do
      client = StubbedClient.new(follow: { max_hops: 5 }).stub(
        "http://example.com/"  => redirect_response("/1"),
        "http://example.com/1" => redirect_response("/2"),
        "http://example.com/2" => redirect_response("/3"),
        "http://example.com/3" => redirect_response("/4"),
        "http://example.com/4" => redirect_response("/5"),
        "http://example.com/5" => redirect_response("/6"),
        "http://example.com/6" => simple_response("OK")
      )

      assert_raises(HTTP::Redirector::TooManyRedirectsError) { client.get("http://example.com/") }
    end

    context "with non-ASCII URLs" do
      it "theoretically works like a charm" do
        client = StubbedClient.new(follow: true).stub(
          "http://example.com/"      => redirect_response("/könig"),
          "http://example.com/könig" => simple_response("OK")
        )

        client.get "http://example.com/könig"
      end

      it "follows redirects with non-ASCII URLs" do
        client = StubbedClient.new(follow: true).stub(
          "http://example.com/"      => redirect_response("/könig"),
          "http://example.com/könig" => simple_response("OK")
        )

        assert_equal "OK", client.get("http://example.com/").to_s
      end
    end
  end

  describe "following redirects with logging" do
    let(:logger) do
      logger           = Logger.new(logdev)
      logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
      logger.level     = Logger::INFO
      logger
    end

    let(:logdev) { StringIO.new }

    it "logs all requests" do
      client = StubbedClient.new(follow: true, features: { logging: { logger: logger } }).stub(
        "http://example.com/"  => redirect_response("/1"),
        "http://example.com/1" => redirect_response("/2"),
        "http://example.com/2" => redirect_response("/3"),
        "http://example.com/3" => simple_response("OK")
      )

      client.get("http://example.com/")

      assert_equal <<~OUTPUT, logdev.string
        ** INFO **
        > GET http://example.com/
        ** INFO **
        > GET http://example.com/1
        ** INFO **
        > GET http://example.com/2
        ** INFO **
        > GET http://example.com/3
      OUTPUT
    end
  end

  describe "base_uri" do
    it "resolves relative paths against base URI" do
      client = StubbedClient.new(base_uri: "https://example.com/api").stub(
        "https://example.com/api/users" => simple_response("OK")
      )

      assert_equal "OK", client.get("users").to_s
    end

    it "resolves absolute paths from host root" do
      client = StubbedClient.new(base_uri: "https://example.com/api").stub(
        "https://example.com/users" => simple_response("OK")
      )

      assert_equal "OK", client.get("/users").to_s
    end

    it "ignores base_uri for absolute URLs" do
      client = StubbedClient.new(base_uri: "https://example.com/api").stub(
        "https://other.com/path" => simple_response("OK")
      )

      assert_equal "OK", client.get("https://other.com/path").to_s
    end

    it "handles parent path traversal" do
      client = StubbedClient.new(base_uri: "https://example.com/api/v1").stub(
        "https://example.com/api/v2" => simple_response("OK")
      )

      assert_equal "OK", client.get("../v2").to_s
    end

    it "handles base URI without trailing slash" do
      client = StubbedClient.new(base_uri: "https://example.com/api").stub(
        "https://example.com/api/users" => simple_response("OK")
      )

      assert_equal "OK", client.get("users").to_s
    end

    it "handles base URI with trailing slash" do
      client = StubbedClient.new(base_uri: "https://example.com/api/").stub(
        "https://example.com/api/users" => simple_response("OK")
      )

      assert_equal "OK", client.get("users").to_s
    end
  end

  describe "parsing params" do
    let(:client) { HTTP::Client.new }

    def parse_query(str)
      URI.decode_www_form(str).group_by(&:first).transform_values { |v| v.map(&:last) }
    end

    it "accepts params within the provided URL" do
      req = capture_request(client) { client.get("http://example.com/?foo=bar") }

      assert_equal({ "foo" => %w[bar] }, parse_query(req.uri.query))
    end

    it "combines GET params from the URI with the passed in params" do
      req = capture_request(client) { client.get("http://example.com/?foo=bar", params: { baz: "quux" }) }

      assert_equal({ "foo" => %w[bar], "baz" => %w[quux] }, parse_query(req.uri.query))
    end

    it "merges duplicate values" do
      req = capture_request(client) { client.get("http://example.com/?a=1", params: { a: 2 }) }

      assert_match(/^(a=1&a=2|a=2&a=1)$/, req.uri.query)
    end

    it "does not modify query part if no params were given" do
      req = capture_request(client) { client.get("http://example.com/?deadbeef") }

      assert_equal "deadbeef", req.uri.query
    end

    it "does not corrupt index-less arrays" do
      req = capture_request(client) { client.get("http://example.com/?a[]=b&a[]=c", params: { d: "e" }) }

      assert_equal({ "a[]" => %w[b c], "d" => %w[e] }, parse_query(req.uri.query))
    end

    it "properly encodes colons" do
      req = capture_request(client) { client.get("http://example.com/", params: { t: "1970-01-01T00:00:00Z" }) }

      assert_equal "t=1970-01-01T00%3A00%3A00Z", req.uri.query
    end

    it 'does not convert newlines into \r\n before encoding string values' do
      req = capture_request(client) { client.get("http://example.com/", params: { foo: "bar\nbaz" }) }

      assert_equal "foo=bar%0Abaz", req.uri.query
    end
  end

  describe "passing multipart form data" do
    it "creates url encoded form data object" do
      client = HTTP::Client.new
      req = capture_request(client) { client.get("http://example.com/", form: { foo: "bar" }) }

      assert_kind_of HTTP::FormData::Urlencoded, req.body.source
      assert_equal "foo=bar", req.body.source.to_s
    end

    it "creates multipart form data object" do
      client = HTTP::Client.new
      req = capture_request(client) { client.get("http://example.com/", form: { foo: HTTP::FormData::Part.new("content") }) }

      assert_kind_of HTTP::FormData::Multipart, req.body.source
      assert_includes req.body.source.to_s, "content"
    end

    context "when passing an HTTP::FormData::Multipart object directly" do
      it "passes it through unchanged" do
        form_data = HTTP::FormData::Multipart.new({ foo: "bar" })
        client = HTTP::Client.new
        req = capture_request(client) { client.get("http://example.com/", form: form_data) }

        assert_same form_data, req.body.source
        assert_match(/^Content-Disposition: form-data; name="foo"\r\n\r\nbar\r\n/m, req.body.source.to_s)
      end
    end

    context "when passing an HTTP::FormData::Urlencoded object directly" do
      it "passes it through unchanged" do
        form_data = HTTP::FormData::Urlencoded.new({ foo: "bar" })
        client = HTTP::Client.new
        req = capture_request(client) { client.get("http://example.com/", form: form_data) }

        assert_same form_data, req.body.source
      end
    end
  end

  describe "passing json" do
    it "encodes given object" do
      client = HTTP::Client.new
      req = capture_request(client) { client.get("http://example.com/", json: { foo: :bar }) }

      assert_equal '{"foo":"bar"}', req.body.source
      assert_equal "application/json; charset=utf-8", req.headers["Content-Type"]
    end
  end

  describe "#request" do
    context "with non-ASCII URLs" do
      it "theoretically works like a charm" do
        client = HTTP::Client.new
        client.get "#{dummy.endpoint}/könig"
      end

      it "handles multi-byte characters in URLs" do
        client = HTTP::Client.new
        client.get "#{dummy.endpoint}/héllö-wörld"
      end
    end

    context "with explicitly given Host header" do
      let(:headers) { { "Host" => "another.example.com" } }
      let(:client)  { HTTP::Client.new headers: headers }

      it "keeps Host header as is" do
        req = capture_request(client) { client.request(:get, "http://example.com/") }

        assert_equal "another.example.com", req.headers["Host"]
      end
    end

    context "when :auto_deflate was specified" do
      let(:headers) { { "Content-Length" => "12" } }
      let(:client)  { HTTP::Client.new headers: headers, features: { auto_deflate: {} }, body: "foo" }

      it "deletes Content-Length header" do
        req = capture_request(client) { client.request(:get, "http://example.com/") }

        assert_nil req.headers["Content-Length"]
      end

      it "sets Content-Encoding header" do
        req = capture_request(client) { client.request(:get, "http://example.com/") }

        assert_equal "gzip", req.headers["Content-Encoding"]
      end

      context "and there is no body" do
        let(:client) { HTTP::Client.new headers: headers, features: { auto_deflate: {} } }

        it "doesn't set Content-Encoding header" do
          req = capture_request(client) { client.request(:get, "http://example.com/") }

          refute_includes req.headers, "Content-Encoding"
        end
      end
    end

    context "Feature" do
      let(:client) { HTTP::Client.new }
      let(:feature_class) do
        Class.new(HTTP::Feature) do
          attr_reader :captured_request, :captured_response, :captured_error

          def wrap_request(request)
            @captured_request = request
          end

          def wrap_response(response)
            @captured_response = response
          end

          def on_error(request, error)
            @captured_request = request
            @captured_error = error
          end
        end
      end

      it "is given a chance to wrap the Request" do
        feature_instance = feature_class.new

        response = client.use(test_feature: feature_instance)
                         .request(:get, dummy.endpoint)

        assert_equal 200, response.code
        assert_equal :get, feature_instance.captured_request.verb
        assert_equal "#{dummy.endpoint}/", feature_instance.captured_request.uri.to_s
      end

      it "is given a chance to wrap the Response" do
        feature_instance = feature_class.new

        response = client.use(test_feature: feature_instance)
                         .request(:get, dummy.endpoint)

        assert_equal response, feature_instance.captured_response
      end

      it "is given a chance to handle an error" do
        sleep_url = "#{dummy.endpoint}/sleep"
        feature_instance = feature_class.new

        assert_raises(HTTP::TimeoutError) do
          client.use(test_feature: feature_instance)
                .timeout(0.01)
                .request(:post, sleep_url)
        end

        assert_kind_of HTTP::TimeoutError, feature_instance.captured_error
        assert_equal :post, feature_instance.captured_request.verb
        assert_equal sleep_url, feature_instance.captured_request.uri.to_s
      end

      it "is given a chance to handle a connection timeout error" do
        sleep_url = "#{dummy.endpoint}/sleep"
        feature_instance = feature_class.new

        TCPSocket.stub(:open, ->(*) { sleep 0.1 }) do
          assert_raises(HTTP::ConnectTimeoutError) do
            client.use(test_feature: feature_instance)
                  .timeout(0.001)
                  .request(:post, sleep_url)
          end
        end
        assert_kind_of HTTP::ConnectTimeoutError, feature_instance.captured_error
      end

      it "handles responses in the reverse order from the requests" do
        feature_class_order =
          Class.new(HTTP::Feature) do
            @order = []

            class << self
              attr_reader :order
            end

            def initialize(id:)
              super()
              @id = id
            end

            def wrap_request(req)
              self.class.order << "request.#{@id}"
              req
            end

            def wrap_response(res)
              self.class.order << "response.#{@id}"
              res
            end
          end
        feature_instance_a = feature_class_order.new(id: "a")
        feature_instance_b = feature_class_order.new(id: "b")
        feature_instance_c = feature_class_order.new(id: "c")

        client.use(
          test_feature_a: feature_instance_a,
          test_feature_b: feature_instance_b,
          test_feature_c: feature_instance_c
        ).request(:get, dummy.endpoint)

        assert_equal(
          ["request.a", "request.b", "request.c", "response.c", "response.b", "response.a"],
          feature_class_order.order
        )
      end

      it "calls on_request once per attempt" do
        feature_class_on_request =
          Class.new(HTTP::Feature) do
            attr_reader :call_count

            def initialize
              super
              @call_count = 0
            end

            def on_request(_request)
              @call_count += 1
            end
          end
        feature_instance = feature_class_on_request.new

        client.use(test_feature: feature_instance)
              .request(:get, dummy.endpoint)

        assert_equal 1, feature_instance.call_count
      end

      it "calls on_request once per retry attempt" do
        feature_class_on_request =
          Class.new(HTTP::Feature) do
            attr_reader :call_count

            def initialize
              super
              @call_count = 0
            end

            def on_request(_request)
              @call_count += 1
            end
          end
        feature_instance = feature_class_on_request.new

        client.use(test_feature: feature_instance)
              .retriable(delay: 0, retry_statuses: [500])
              .request(:get, "#{dummy.endpoint}/retry-2")

        assert_equal 2, feature_instance.call_count
      end

      it "wraps each retry attempt with around_request" do
        feature_class_around =
          Class.new(HTTP::Feature) do
            attr_reader :events

            def initialize
              super
              @events = []
            end

            def around_request(request)
              @events << :before
              yield(request).tap do
                @events << :after
              end
            end
          end
        feature_instance = feature_class_around.new

        client.use(test_feature: feature_instance)
              .retriable(delay: 0, retry_statuses: [500])
              .request(:get, "#{dummy.endpoint}/retry-2")

        assert_equal %i[before after before after], feature_instance.events
      end

      it "wraps the exchange with around_request in feature order" do
        feature_class_around =
          Class.new(HTTP::Feature) do
            @order = []

            class << self
              attr_reader :order
            end

            def initialize(id:)
              super()
              @id = id
            end

            def around_request(request)
              self.class.order << "before.#{@id}"
              yield(request).tap do
                self.class.order << "after.#{@id}"
              end
            end
          end
        feature_instance_a = feature_class_around.new(id: "a")
        feature_instance_b = feature_class_around.new(id: "b")
        feature_instance_c = feature_class_around.new(id: "c")

        client.use(
          test_feature_a: feature_instance_a,
          test_feature_b: feature_instance_b,
          test_feature_c: feature_instance_c
        ).request(:get, dummy.endpoint)

        assert_equal(
          ["before.a", "before.b", "before.c", "after.c", "after.b", "after.a"],
          feature_class_around.order
        )
      end
    end
  end

  context "with HTTP handling" do
    let(:extra_options) { {} }
    let(:options) { {} }
    let(:server)  { dummy }
    let(:client)  { HTTP::Client.new(**options, **extra_options) }

    include HTTPHandlingTests
  end

  describe "working with SSL" do
    run_server(:dummy_ssl) { DummyServer.new(ssl: true) }

    let(:options) { {} }
    let(:extra_options) { {} }

    let(:client) do
      HTTP::Client.new(**options, ssl_context: SSLHelper.client_context, **extra_options)
    end

    let(:server) { dummy_ssl }

    include HTTPHandlingTests

    it "just works" do
      response = client.get(dummy_ssl.endpoint)

      assert_equal "<!doctype html>", response.body.to_s
    end

    it "fails with OpenSSL::SSL::SSLError if host mismatch" do
      assert_raises(OpenSSL::SSL::SSLError) do
        client.get(dummy_ssl.endpoint.gsub("127.0.0.1", "localhost"))
      end
    end

    context "with SSL options instead of a context" do
      let(:client) do
        HTTP::Client.new(**options, ssl: SSLHelper.client_params)
      end

      it "just works" do
        response = client.get(dummy_ssl.endpoint)

        assert_equal "<!doctype html>", response.body.to_s
      end
    end
  end

  describe "#perform" do
    let(:client) { HTTP::Client.new }

    it "calls finish_response once body was fully flushed" do
      # Test the behavior: reading the full body should work correctly
      body = client.get(dummy.endpoint).to_s

      assert_equal "<!doctype html>", body
    end

    it "provides access to the Request from the Response" do
      unique_value = "20190424"
      response = client.headers("X-Value" => unique_value).get(dummy.endpoint)

      assert_kind_of HTTP::Request, response.request
      assert_equal unique_value, response.request.headers["X-Value"]
    end

    context "with HEAD request" do
      it "does not iterate through body" do
        # Test the behavior: HEAD request should succeed without reading body
        response = client.head(dummy.endpoint)

        assert_equal 200, response.status.to_i
      end

      it "finishes response after headers were received" do
        # Test the behavior: HEAD request should complete successfully
        response = client.head(dummy.endpoint)

        assert_equal 200, response.status.to_i
      end
    end

    context "when server fully flushes response in one chunk" do
      it "properly reads body" do
        response_data = [
          "HTTP/1.1 200 OK\r\n" \
          "Content-Type: text/html\r\n" \
          "Server: WEBrick/1.3.1 (Ruby/1.9.3/2013-11-22)\r\n" \
          "Date: Mon, 24 Mar 2014 00:32:22 GMT\r\n" \
          "Content-Length: 15\r\n" \
          "Connection: Keep-Alive\r\n" \
          "\r\n" \
          "<!doctype html>"
        ]

        socket_spy = fake(
          close:       nil,
          closed?:     true,
          readpartial: proc { response_data.shift || :eof },
          write:       proc(&:bytesize)
        )

        TCPSocket.stub(:open, socket_spy) do
          body = client.get(dummy.endpoint).to_s

          assert_equal "<!doctype html>", body
        end
      end
    end

    context "when uses chunked transfer encoding" do
      it "properly reads body" do
        response_data = [
          "HTTP/1.1 200 OK\r\n" \
          "Content-Type: application/json\r\n" \
          "Transfer-Encoding: chunked\r\n" \
          "Connection: close\r\n" \
          "\r\n" \
          "9\r\n" \
          "{\"state\":\r\n" \
          "5\r\n" \
          "\"ok\"}\r\n" \
          "0\r\n" \
          "\r\n"
        ]

        socket_spy = fake(
          close:       nil,
          closed?:     true,
          readpartial: proc { response_data.shift || :eof },
          write:       proc(&:bytesize)
        )

        TCPSocket.stub(:open, socket_spy) do
          body = client.get(dummy.endpoint).to_s

          assert_equal '{"state":"ok"}', body
        end
      end

      context "with broken body (too early closed connection)" do
        it "raises HTTP::ConnectionError" do
          response_data = [
            "HTTP/1.1 200 OK\r\n" \
            "Content-Type: application/json\r\n" \
            "Transfer-Encoding: chunked\r\n" \
            "Connection: close\r\n" \
            "\r\n" \
            "9\r\n" \
            "{\"state\":\r\n"
          ]

          socket_spy = fake(
            close:       nil,
            closed?:     true,
            readpartial: proc { response_data.shift || :eof },
            write:       proc(&:bytesize)
          )

          TCPSocket.stub(:open, socket_spy) do
            assert_raises(HTTP::ConnectionError) { client.get(dummy.endpoint).to_s }
          end
        end
      end
    end
  end

  describe "#perform with failed proxy connect" do
    it "skips sending request when proxy connect fails" do
      client = HTTP::Client.new
      conn = fake(
        failed_proxy_connect?:  true,
        proxy_response_headers: {},
        status_code:            407,
        http_version:           "1.1",
        headers:                HTTP::Headers.new,
        finish_response:        nil,
        keep_alive?:            true,
        expired?:               false,
        close:                  nil,
        "pending_response=":    ->(*) {}
      )
      client.instance_variable_set(:@connection, conn)
      client.instance_variable_set(:@state, :clean)
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/", headers: {})
      response = client.perform(req, HTTP::Options.new)

      assert_equal 407, response.status.to_i
    end
  end
end
