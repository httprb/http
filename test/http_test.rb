# frozen_string_literal: true

require "test_helper"

require "json"

require "support/dummy_server"
require "support/proxy_server"

describe HTTP do
  cover "HTTP::Chainable*"
  run_server(:dummy) { DummyServer.new }
  run_server(:dummy_ssl) { DummyServer.new(ssl: true) }

  let(:ssl_client) do
    HTTP::Client.new ssl_context: SSLHelper.client_context
  end

  context "getting resources" do
    it "is easy" do
      response = HTTP.get dummy.endpoint

      assert_match(/<!doctype html>/, response.to_s)
    end

    context "with URI instance" do
      it "is easy" do
        response = HTTP.get HTTP::URI.parse(dummy.endpoint)

        assert_match(/<!doctype html>/, response.to_s)
      end
    end

    context "with query string parameters" do
      it "is easy" do
        response = HTTP.get "#{dummy.endpoint}/params", params: { foo: "bar" }

        assert_match(/Params!/, response.to_s)
      end
    end

    context "with query string parameters in the URI and opts hash" do
      it "includes both" do
        response = HTTP.get "#{dummy.endpoint}/multiple-params?foo=bar", params: { baz: "quux" }

        assert_match(/More Params!/, response.to_s)
      end
    end

    context "with two leading slashes in path" do
      it "is allowed" do
        HTTP.get "#{dummy.endpoint}//"
      end
    end

    context "with headers" do
      it "is easy" do
        response = HTTP.accept("application/json").get dummy.endpoint

        assert_includes response.to_s, "json"
      end
    end

    context "with a large request body" do
      let(:request_body) { "\xE2\x80\x9C" * 1_000_000 } # use multi-byte character

      [:null, 6, { read: 2, write: 2, connect: 2 }, { global: 6, read: 2, write: 2, connect: 2 }].each do |timeout|
        context "with `.timeout(#{timeout.inspect})`" do
          let(:client) { HTTP.timeout(timeout) }

          it "writes the whole body" do
            response = client.post "#{dummy.endpoint}/echo-body", body: request_body

            assert_equal request_body.b, response.body.to_s
            assert_equal request_body.bytesize, response.headers["Content-Length"].to_i
          end
        end
      end
    end
  end

  describe ".via" do
    context "anonymous proxy" do
      run_server(:proxy) { ProxyServer.new }

      it "proxies the request" do
        response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

        assert_equal "true", response.headers["X-Proxied"]
      end

      it "responds with the endpoint's body" do
        response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

        assert_match(/<!doctype html>/, response.to_s)
      end

      it "raises an argument error if no port given" do
        assert_raises(HTTP::RequestError) { HTTP.via(proxy.addr) }
      end

      it "ignores credentials" do
        response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

        assert_match(/<!doctype html>/, response.to_s)
      end

      context "ssl" do
        it "responds with the endpoint's body" do
          response = ssl_client.via(proxy.addr, proxy.port).get dummy_ssl.endpoint

          assert_match(/<!doctype html>/, response.to_s)
        end

        it "ignores credentials" do
          response = ssl_client.via(proxy.addr, proxy.port, "username", "password").get dummy_ssl.endpoint

          assert_match(/<!doctype html>/, response.to_s)
        end
      end
    end

    context "proxy with authentication" do
      run_server(:proxy) { AuthProxyServer.new }

      it "proxies the request" do
        response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

        assert_equal "true", response.headers["X-Proxied"]
      end

      it "responds with the endpoint's body" do
        response = HTTP.via(proxy.addr, proxy.port, "username", "password").get dummy.endpoint

        assert_match(/<!doctype html>/, response.to_s)
      end

      it "responds with 407 when wrong credentials given" do
        response = HTTP.via(proxy.addr, proxy.port, "user", "pass").get dummy.endpoint

        assert_equal 407, response.status.to_i
      end

      it "responds with 407 if no credentials given" do
        response = HTTP.via(proxy.addr, proxy.port).get dummy.endpoint

        assert_equal 407, response.status.to_i
      end

      context "ssl" do
        it "responds with the endpoint's body" do
          response = ssl_client.via(proxy.addr, proxy.port, "username", "password").get dummy_ssl.endpoint

          assert_match(/<!doctype html>/, response.to_s)
        end

        it "responds with 407 when wrong credentials given" do
          response = ssl_client.via(proxy.addr, proxy.port, "user", "pass").get dummy_ssl.endpoint

          assert_equal 407, response.status.to_i
        end

        it "responds with 407 if no credentials given" do
          response = ssl_client.via(proxy.addr, proxy.port).get dummy_ssl.endpoint

          assert_equal 407, response.status.to_i
        end
      end
    end

    context "with proxy headers as third argument" do
      it "sets proxy_headers from hash in position 3" do
        client = HTTP.via("proxy.example.com", 8080, { "X-Custom" => "val" })
        proxy = client.default_options.proxy

        assert_equal({ "X-Custom" => "val" }, proxy[:proxy_headers])
      end
    end

    context "with proxy headers as fifth argument" do
      it "sets proxy_headers from hash in position 5" do
        hdrs = { "X-Custom" => "val" }
        client = HTTP.via("proxy.example.com", 8080, "user", "pass", hdrs)
        proxy = client.default_options.proxy

        assert_equal({ "X-Custom" => "val" }, proxy[:proxy_headers])
      end
    end

    context "with non-string first argument" do
      it "skips proxy_address when first arg is not a String" do
        client = HTTP.via(nil, 8080, { "X-Custom" => "val" })
        proxy = client.default_options.proxy

        refute proxy.key?(:proxy_address)
      end
    end
  end

  describe ".retry" do
    it "ensures endpoint counts retries" do
      assert_equal "retried 1x", HTTP.get("#{dummy.endpoint}/retry-2").to_s
      assert_equal "retried 2x", HTTP.get("#{dummy.endpoint}/retry-2").to_s
    end

    it "retries the request" do
      response = HTTP.retriable(delay: 0, retry_statuses: 500...600).get "#{dummy.endpoint}/retry-2"

      assert_equal "retried 2x", response.to_s
    end

    it "retries the request and gives us access to the failed requests" do
      err = nil
      retry_callback = ->(_, _, res) { assert_match(/^retried \dx$/, res.to_s) }
      begin
        HTTP.retriable(
          should_retry: ->(*) { true },
          tries:        3,
          delay:        0,
          on_retry:     retry_callback
        ).get "#{dummy.endpoint}/retry-2"
      rescue HTTP::Error => e
        err = e
      end

      assert_equal "retried 3x", err.response.to_s
    end
  end

  context "posting forms to resources" do
    it "is easy" do
      response = HTTP.post "#{dummy.endpoint}/form", form: { example: "testing-form" }

      assert_equal "passed :)", response.to_s
    end
  end

  context "loading binary data" do
    it "is encoded as bytes" do
      response = HTTP.get "#{dummy.endpoint}/bytes"

      assert_equal Encoding::BINARY, response.to_s.encoding
    end
  end

  context "loading endpoint with charset" do
    it "uses charset from headers" do
      response = HTTP.get "#{dummy.endpoint}/iso-8859-1"

      assert_equal Encoding::ISO8859_1, response.to_s.encoding
      assert_equal "testæ", response.to_s.encode(Encoding::UTF_8)
    end

    context "with encoding option" do
      it "respects option" do
        response = HTTP.get "#{dummy.endpoint}/iso-8859-1", encoding: Encoding::BINARY

        assert_equal Encoding::BINARY, response.to_s.encoding
      end
    end
  end

  context "passing a string encoding type" do
    it "finds encoding" do
      response = HTTP.get dummy.endpoint, encoding: "ascii"

      assert_equal Encoding::ASCII, response.to_s.encoding
    end
  end

  context "loading text with no charset" do
    it "is binary encoded" do
      response = HTTP.get dummy.endpoint

      assert_equal Encoding::BINARY, response.to_s.encoding
    end
  end

  context "posting with an explicit body" do
    it "is easy" do
      response = HTTP.post "#{dummy.endpoint}/body", body: "testing-body"

      assert_equal "passed :)", response.to_s
    end
  end

  context "with redirects" do
    it "is easy for 301" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-301")

      assert_match(/<!doctype html>/, response.to_s)
    end

    it "is easy for 302" do
      response = HTTP.follow.get("#{dummy.endpoint}/redirect-302")

      assert_match(/<!doctype html>/, response.to_s)
    end
  end

  context "head requests" do
    it "is easy" do
      response = HTTP.head dummy.endpoint

      assert_equal 200, response.status.to_i
      assert_match(/html/, response.headers["content-type"])
    end
  end

  describe ".auth" do
    it "sets Authorization header to the given value" do
      client = HTTP.auth "abc"

      assert_equal "abc", client.default_options.headers[:authorization]
    end

    it "accepts any #to_s object" do
      client = HTTP.auth fake(to_s: "abc")

      assert_equal "abc", client.default_options.headers[:authorization]
    end
  end

  describe ".basic_auth" do
    it "fails when options is not a Hash" do
      assert_raises(NoMethodError) { HTTP.basic_auth "[FOOBAR]" }
    end

    it "fails when :pass is not given" do
      assert_raises(KeyError) { HTTP.basic_auth user: "[USER]" }
    end

    it "fails when :user is not given" do
      assert_raises(KeyError) { HTTP.basic_auth pass: "[PASS]" }
    end

    it "sets Authorization header with proper BasicAuth value" do
      client = HTTP.basic_auth user: "foo", pass: "bar"

      assert_match(%r{^Basic [A-Za-z0-9+/]+=*$}, client.default_options.headers[:authorization])
    end
  end

  describe ".persistent" do
    let(:host) { dummy.endpoint }

    context "with host only given" do
      let(:persistent_client) { HTTP.persistent host }

      it "returns an HTTP::Client" do
        assert_kind_of HTTP::Client, persistent_client
      end

      it "is persistent" do
        assert_predicate persistent_client, :persistent?
      end
    end

    context "with host and block given" do
      it "returns last evaluation of last expression" do
        assert_equal :http, HTTP.persistent(host) { :http }
      end

      it "auto-closes connection" do
        closed = false
        HTTP.persistent host do |pclient|
          original_close = pclient.method(:close)
          pclient.define_singleton_method(:close) do
            closed = true
            original_close.call
          end
          pclient.get("/")
        end

        assert closed, "expected close to have been called"
      end
    end

    context "when initialization raises" do
      it "handles nil client in ensure" do
        opts = HTTP.default_options

        opts.stub(:merge, ->(*) { raise "boom" }) do
          assert_raises(RuntimeError) { HTTP.persistent(host) { nil } }
        end
      end
    end

    context "with timeout specified" do
      let(:persistent_client) { HTTP.persistent host, timeout: 100 }

      it "sets keep_alive_timeout" do
        options = persistent_client.default_options

        assert_equal 100, options.keep_alive_timeout
      end
    end
  end

  describe ".timeout" do
    context "specifying a null timeout" do
      let(:client) { HTTP.timeout :null }

      it "sets timeout_class to Null" do
        assert_equal HTTP::Timeout::Null, client.default_options.timeout_class
      end
    end

    context "specifying per operation timeouts" do
      let(:client) { HTTP.timeout read: 123 }

      it "sets timeout_class to PerOperation" do
        assert_equal HTTP::Timeout::PerOperation, client.default_options.timeout_class
      end

      it "sets given timeout options" do
        assert_equal({ read_timeout: 123 }, client.default_options.timeout_options)
      end
    end

    context "specifying per operation timeouts with long form keys" do
      let(:client) { HTTP.timeout read_timeout: 123 }

      it "sets given timeout options" do
        assert_equal({ read_timeout: 123 }, client.default_options.timeout_options)
      end
    end

    context "specifying all per operation timeouts" do
      let(:client) { HTTP.timeout read: 1, write: 2, connect: 3 }

      it "sets all timeout options" do
        assert_equal({ read_timeout: 1, write_timeout: 2, connect_timeout: 3 }, client.default_options.timeout_options)
      end
    end

    context "specifying per operation timeouts as frozen hash" do
      let(:frozen_options) { { read: 123 }.freeze }
      let(:client) { HTTP.timeout(frozen_options) }

      it "does not raise an error" do
        client
      end
    end

    context "with empty hash" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout({}) }
      end
    end

    context "with unknown timeout key" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout(timeout: 2) }
      end
    end

    context "with both short and long form of same key" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout(read: 2, read_timeout: 2) }
      end
    end

    context "with non-numeric timeout value" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout(read: "2") }
      end
    end

    context "with string keys" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout("read" => 2) }
      end
    end

    context "specifying global timeout as hash key" do
      let(:client) { HTTP.timeout global: 60 }

      it "sets timeout_class to Global" do
        assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
      end

      it "sets given timeout option" do
        assert_equal({ global_timeout: 60 }, client.default_options.timeout_options)
      end
    end

    context "specifying global timeout with long form hash key" do
      let(:client) { HTTP.timeout global_timeout: 60 }

      it "sets timeout_class to Global" do
        assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
      end

      it "sets given timeout option" do
        assert_equal({ global_timeout: 60 }, client.default_options.timeout_options)
      end
    end

    context "specifying combined global and per-operation timeouts" do
      let(:client) { HTTP.timeout global: 60, read: 30, write: 20, connect: 5 }

      it "sets timeout_class to Global" do
        assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
      end

      it "sets all timeout options" do
        expected = { read_timeout: 30, write_timeout: 20, connect_timeout: 5, global_timeout: 60 }

        assert_equal expected, client.default_options.timeout_options
      end
    end

    context "specifying combined global and partial per-operation timeouts" do
      let(:client) { HTTP.timeout global: 60, read: 30 }

      it "sets timeout_class to Global" do
        assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
      end

      it "includes both global and per-op options" do
        expected = { read_timeout: 30, global_timeout: 60 }

        assert_equal expected, client.default_options.timeout_options
      end
    end

    context "with both short and long form of global key" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout(global: 60, global_timeout: 60) }
      end
    end

    context "with non-numeric global value" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout(global: "60") }
      end
    end

    context "specifying a global timeout" do
      let(:client) { HTTP.timeout 123 }

      it "sets timeout_class to Global" do
        assert_equal HTTP::Timeout::Global, client.default_options.timeout_class
      end

      it "sets given timeout option" do
        assert_equal({ global_timeout: 123 }, client.default_options.timeout_options)
      end
    end

    context "specifying a float global timeout" do
      let(:client) { HTTP.timeout 2.5 }

      it "sets given timeout option" do
        assert_equal({ global_timeout: 2.5 }, client.default_options.timeout_options)
      end
    end

    context "with unsupported options" do
      it "raises ArgumentError" do
        assert_raises(ArgumentError) { HTTP.timeout("invalid") }
      end
    end
  end

  describe ".cookies" do
    let(:endpoint) { "#{dummy.endpoint}/cookies" }

    it "passes correct Cookie header" do
      assert_equal "abc: def", HTTP.cookies(abc: :def).get(endpoint).to_s
    end

    it "properly works with cookie jars from response" do
      res = HTTP.get(endpoint).flush

      assert_equal "foo: bar", HTTP.cookies(res.cookies).get(endpoint).to_s
    end

    it "properly merges cookies" do
      res     = HTTP.get(endpoint).flush
      client  = HTTP.cookies(foo: 123, bar: 321).cookies(res.cookies)

      assert_equal "foo: bar\nbar: 321", client.get(endpoint).to_s
    end

    it "properly merges Cookie headers and cookies" do
      client = HTTP.headers("Cookie" => "foo=bar").cookies(baz: :moo)

      assert_equal "foo: bar\nbaz: moo", client.get(endpoint).to_s
    end
  end

  describe ".nodelay" do
    let(:socket_spy_class) do
      Class.new(TCPSocket) do
        def self.setsockopt_calls
          @setsockopt_calls ||= []
        end

        def setsockopt(*args)
          self.class.setsockopt_calls << args
          super
        end
      end
    end

    before do
      HTTP.default_options = { socket_class: socket_spy_class }
    end

    after do
      HTTP.default_options = {}
    end

    it "sets TCP_NODELAY on the underlying socket" do
      HTTP.get(dummy.endpoint)

      assert_equal [], socket_spy_class.setsockopt_calls
      HTTP.nodelay.get(dummy.endpoint)

      assert_equal [[Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1]], socket_spy_class.setsockopt_calls
    end
  end

  describe ".use" do
    it "turns on given feature" do
      client = HTTP.use :auto_deflate

      assert_equal [:auto_deflate], client.default_options.features.keys
    end

    context "with :auto_deflate" do
      it "sends gzipped body" do
        client   = HTTP.use :auto_deflate
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/echo-body", body: body)
        encoded  = response.to_s

        assert_equal body, Zlib::GzipReader.new(StringIO.new(encoded)).read
      end

      it "sends deflated body" do
        client   = HTTP.use auto_deflate: { method: "deflate" }
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/echo-body", body: body)
        encoded  = response.to_s

        assert_equal body, Zlib::Inflate.inflate(encoded)
      end
    end

    context "with :auto_inflate" do
      it "returns raw body when Content-Encoding type is missing" do
        client   = HTTP.use :auto_inflate
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/encoded-body", body: body)

        assert_equal "#{body}-raw", response.to_s
      end

      it "returns decoded body" do
        client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "gzip")
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/encoded-body", body: body)

        assert_equal "#{body}-gzipped", response.to_s
      end

      it "returns deflated body" do
        client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "deflate")
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/encoded-body", body: body)

        assert_equal "#{body}-deflated", response.to_s
      end

      it "returns empty body for no content response where Content-Encoding is gzip" do
        client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "gzip")
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/no-content-204", body: body)

        assert_equal "", response.to_s
      end

      it "returns empty body for no content response where Content-Encoding is deflate" do
        client   = HTTP.use(:auto_inflate).headers("Accept-Encoding" => "deflate")
        body     = "Hello!"
        response = client.post("#{dummy.endpoint}/no-content-204", body: body)

        assert_equal "", response.to_s
      end
    end

    context "with :normalize_uri" do
      it "normalizes URI" do
        response = HTTP.get "#{dummy.endpoint}/héllö-wörld"

        assert_equal "hello world", response.to_s
      end

      it "uses the custom URI Normalizer method" do
        client = HTTP.use(normalize_uri: { normalizer: :itself.to_proc })
        response = client.get("#{dummy.endpoint}/héllö-wörld")

        assert_equal 400, response.status.to_i
      end

      it "raises if custom URI Normalizer returns invalid path" do
        client = HTTP.use(normalize_uri: { normalizer: :itself.to_proc })
        err = assert_raises(HTTP::RequestError) { client.get("#{dummy.endpoint}/hello\nworld") }
        assert_equal 'Invalid request URI: "/hello\nworld"', err.message
      end

      it "raises if custom URI Normalizer returns invalid host" do
        normalizer = lambda do |uri|
          uri.port = nil
          uri.instance_variable_set(:@host, "example\ncom")
          uri
        end
        client = HTTP.use(normalize_uri: { normalizer: normalizer })
        err = assert_raises(HTTP::RequestError) { client.get(dummy.endpoint) }
        assert_equal 'Invalid host: "example\ncom"', err.message
      end

      it "uses the default URI normalizer" do
        client = HTTP.use :normalize_uri
        response = client.get("#{dummy.endpoint}/héllö-wörld")

        assert_equal "hello world", response.to_s
      end
    end
  end

  %i[put delete trace options connect patch].each do |verb|
    describe ".#{verb}" do
      it "delegates to #request" do
        mock_client = Minitest::Mock.new
        mock_client.expect(:request, nil, [verb, "http://example.com/", {}])
        HTTP::Client.stub(:new, mock_client) do
          HTTP.public_send(verb, "http://example.com/")
        end
        mock_client.verify
      end
    end
  end

  describe ".build_request" do
    it "returns an HTTP::Request" do
      req = HTTP.build_request(:get, "http://example.com/")

      assert_kind_of HTTP::Request, req
    end
  end

  describe ".encoding" do
    it "returns a session with the specified encoding" do
      session = HTTP::Client.new.encoding("UTF-8")

      assert_kind_of HTTP::Session, session
    end
  end

  it "unifies socket errors into HTTP::ConnectionError" do
    original_open = TCPSocket.method(:open)
    stub_open = lambda do |*args|
      raise SocketError if args[0] == "thishostshouldnotexists.com"

      original_open.call(*args)
    end
    TCPSocket.stub(:open, stub_open) do
      assert_raises(HTTP::ConnectionError) { HTTP.get "http://thishostshouldnotexists.com" }
      assert_raises(HTTP::ConnectionError) { HTTP.get "http://127.0.0.1:111" }
    end
  end
end
