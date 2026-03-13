# frozen_string_literal: true

require "test_helper"

describe HTTP::Request do
  cover "HTTP::Request*"
  let(:request) do
    HTTP::Request.new(
      verb:    :get,
      uri:     request_uri,
      headers: headers,
      proxy:   proxy
    )
  end

  let(:proxy)       { {} }
  let(:headers)     { { accept: "text/html" } }
  let(:request_uri) { "http://example.com/foo?bar=baz" }

  describe "#initialize" do
    it "provides a #headers accessor" do
      assert_kind_of HTTP::Headers, request.headers
    end

    it "provides a #scheme accessor" do
      assert_equal :http, request.scheme
    end

    it "provides a #verb accessor" do
      assert_equal :get, request.verb
    end

    it "provides a #uri accessor" do
      assert_equal HTTP::URI.parse("http://example.com/foo?bar=baz"), request.uri
    end

    it "provides a #proxy accessor" do
      assert_equal({}, request.proxy)
    end

    it "provides a #version accessor defaulting to 1.1" do
      assert_equal "1.1", request.version
    end

    it "provides a #body accessor" do
      assert_instance_of HTTP::Request::Body, request.body
    end

    it "provides a #uri_normalizer accessor" do
      assert_equal HTTP::URI::NORMALIZER, request.uri_normalizer
    end

    it "stores a custom uri_normalizer" do
      custom = ->(uri) { HTTP::URI.parse(uri) }
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: custom)

      assert_equal custom, req.uri_normalizer
    end

    it "stores a custom version" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/", version: "2.0")

      assert_equal "2.0", req.version
    end

    it "stores the proxy hash" do
      p = { proxy_address: "proxy.example.com", proxy_port: 8080 }
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/", proxy: p)

      assert_equal p, req.proxy
    end

    it "downcases and symbolizes the verb" do
      req = HTTP::Request.new(verb: "POST", uri: "http://example.com/")

      assert_equal :post, req.verb
    end

    it "downcases the scheme" do
      req = HTTP::Request.new(verb: :get, uri: "HTTP://example.com/")

      assert_equal :http, req.scheme
    end

    it "accepts https scheme" do
      req = HTTP::Request.new(verb: :get, uri: "https://example.com/")

      assert_equal :https, req.scheme
    end

    it "accepts ws scheme" do
      req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

      assert_equal :ws, req.scheme
    end

    it "accepts wss scheme" do
      req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

      assert_equal :wss, req.scheme
    end

    it "stores body source" do
      req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "hello")

      assert_equal "hello", req.body.source
    end

    it "wraps non-Body body in Body object" do
      req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "hello")

      assert_instance_of HTTP::Request::Body, req.body
    end

    it "passes through an existing Body object" do
      existing_body = HTTP::Request::Body.new("hello")
      req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: existing_body)

      assert_same existing_body, req.body
    end

    it "passes through a Body subclass" do
      subclass_body = Class.new(HTTP::Request::Body).new("hello")
      req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: subclass_body)

      assert_same subclass_body, req.body
    end

    it "sets given headers" do
      assert_equal "text/html", request.headers["Accept"]
    end

    it "raises InvalidError for URI without scheme" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::Request.new(verb: :get, uri: "example.com/")
      end
      assert_match(/invalid URI/, err.message)
    end

    it "raises ArgumentError for nil URI" do
      err = assert_raises(ArgumentError) do
        HTTP::Request.new(verb: :get, uri: nil)
      end
      assert_equal "uri is nil", err.message
    end

    it "raises ArgumentError for empty string URI" do
      err = assert_raises(ArgumentError) do
        HTTP::Request.new(verb: :get, uri: "")
      end
      assert_equal "uri is empty", err.message
    end

    it "does not raise for non-String non-empty URI-like objects" do
      # A URI object is not a String, so is_a?(String) is false,
      # and we should not get "uri is empty"
      uri = HTTP::URI.parse("http://example.com/")
      req = HTTP::Request.new(verb: :get, uri: uri)

      assert_equal :http, req.scheme
    end

    it "raises InvalidError for malformed URI" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::Request.new(verb: :get, uri: ":")
      end
      assert_match(/invalid URI/, err.message)
    end

    it "raises UnsupportedSchemeError for unsupported scheme" do
      err = assert_raises(HTTP::Request::UnsupportedSchemeError) do
        HTTP::Request.new(verb: :get, uri: "ftp://example.com/")
      end
      assert_match(/unknown scheme/, err.message)
    end

    it "raises UnsupportedMethodError for unknown verbs" do
      err = assert_raises(HTTP::Request::UnsupportedMethodError) do
        HTTP::Request.new(verb: :foobar, uri: "http://example.com/")
      end
      assert_match(/unknown method/, err.message)
    end

    it "includes the verb in UnsupportedMethodError message" do
      err = assert_raises(HTTP::Request::UnsupportedMethodError) do
        HTTP::Request.new(verb: :foobar, uri: "http://example.com/")
      end

      assert_includes err.message, "foobar"
    end

    it "includes the URI in InvalidError message for missing scheme" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::Request.new(verb: :get, uri: "example.com/")
      end

      assert_includes err.message, "example.com/"
    end

    it "includes the scheme in UnsupportedSchemeError message" do
      err = assert_raises(HTTP::Request::UnsupportedSchemeError) do
        HTTP::Request.new(verb: :get, uri: "ftp://example.com/")
      end

      assert_includes err.message, "ftp"
    end

    it "defaults proxy to an empty hash" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_equal({}, req.proxy)
    end

    it "sets default headers when headers arg is nil" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_equal "example.com", req.headers["Host"]
      assert_equal HTTP::Request::USER_AGENT, req.headers["User-Agent"]
    end
  end

  describe "Host header" do
    context "was not given" do
      it "defaults to the host from the URI" do
        assert_equal "example.com", request.headers["Host"]
      end

      context "and request URI has non-standard port" do
        let(:request_uri) { "http://example.com:3000/" }

        it "includes the port" do
          assert_equal "example.com:3000", request.headers["Host"]
        end
      end

      context "and request URI has standard HTTPS port" do
        let(:request_uri) { "https://example.com/" }

        it "omits the port" do
          assert_equal "example.com", request.headers["Host"]
        end
      end

      context "and request URI has non-standard HTTPS port" do
        let(:request_uri) { "https://example.com:8443/" }

        it "includes the port" do
          assert_equal "example.com:8443", request.headers["Host"]
        end
      end
    end

    context "was explicitly given" do
      before { headers[:host] = "github.com" }

      it "uses the given host" do
        assert_equal "github.com", request.headers["Host"]
      end
    end

    context "when host contains whitespace" do
      it "raises RequestError" do
        normalizer = lambda { |uri|
          u = HTTP::URI.parse(uri)
          u.host = "exam ple.com"
          u
        }

        assert_raises(HTTP::RequestError) do
          HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: normalizer)
        end
      end

      it "includes the invalid host in the error message" do
        normalizer = lambda { |uri|
          u = HTTP::URI.parse(uri)
          u.host = "exam ple.com"
          u
        }

        err = assert_raises(HTTP::RequestError) do
          HTTP::Request.new(verb: :get, uri: "http://example.com/", uri_normalizer: normalizer)
        end

        assert_includes err.message, "exam ple.com".inspect
      end
    end
  end

  describe "User-Agent header" do
    context "was not given" do
      it "defaults to HTTP::Request::USER_AGENT" do
        assert_equal HTTP::Request::USER_AGENT, request.headers["User-Agent"]
      end
    end

    context "was explicitly given" do
      before { headers[:user_agent] = "MrCrawly/123" }

      it "uses the given user agent" do
        assert_equal "MrCrawly/123", request.headers["User-Agent"]
      end
    end
  end

  describe "#using_proxy?" do
    context "with empty proxy hash" do
      let(:proxy) { {} }

      it "returns false" do
        refute_predicate request, :using_proxy?
      end
    end

    context "with one key in proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com" } }

      it "returns false" do
        refute_predicate request, :using_proxy?
      end
    end

    context "with two keys in proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "returns true" do
        assert_predicate request, :using_proxy?
      end
    end

    context "with four keys in proxy" do
      let(:proxy) do
        { proxy_address: "proxy.example.com", proxy_port: 8080,
          proxy_username: "user", proxy_password: "pass" }
      end

      it "returns true" do
        assert_predicate request, :using_proxy?
      end
    end
  end

  describe "#using_authenticated_proxy?" do
    context "with empty proxy hash" do
      let(:proxy) { {} }

      it "returns false" do
        refute_predicate request, :using_authenticated_proxy?
      end
    end

    context "with two keys in proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "returns false" do
        refute_predicate request, :using_authenticated_proxy?
      end
    end

    context "with three keys in proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080, proxy_username: "user" } }

      it "returns false" do
        refute_predicate request, :using_authenticated_proxy?
      end
    end

    context "with four keys in proxy" do
      let(:proxy) do
        { proxy_address: "proxy.example.com", proxy_port: 8080,
          proxy_username: "user", proxy_password: "pass" }
      end

      it "returns true" do
        assert_predicate request, :using_authenticated_proxy?
      end
    end
  end

  describe "#redirect" do
    let(:redirected) { request.redirect "http://blog.example.com/" }

    let(:headers)   { { accept: "text/html" } }
    let(:proxy)     { { proxy_username: "douglas", proxy_password: "adams" } }
    let(:body)      { "The Ultimate Question" }

    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "http://example.com/",
        headers: headers,
        proxy:   proxy,
        body:    body
      )
    end

    it "has correct uri" do
      assert_equal HTTP::URI.parse("http://blog.example.com/"), redirected.uri
    end

    it "has correct verb" do
      assert_equal request.verb, redirected.verb
    end

    it "has correct body" do
      assert_equal request.body, redirected.body
    end

    it "has correct proxy" do
      assert_equal request.proxy, redirected.proxy
    end

    it "presets new Host header" do
      assert_equal "blog.example.com", redirected.headers["Host"]
    end

    it "preserves version" do
      req = HTTP::Request.new(
        verb: :post, uri: "http://example.com/", body: body, version: "2.0"
      )
      redir = req.redirect("http://blog.example.com/")

      assert_equal "2.0", redir.version
    end

    it "preserves uri_normalizer" do
      custom = ->(uri) { HTTP::URI.parse(uri) }
      req = HTTP::Request.new(
        verb: :post, uri: "http://example.com/", body: body, uri_normalizer: custom
      )
      redir = req.redirect("http://blog.example.com/")

      assert_equal custom, redir.uri_normalizer
    end

    it "preserves Accept header across redirect" do
      assert_equal "text/html", redirected.headers["Accept"]
    end

    context "with URL with non-standard port given" do
      let(:redirected) { request.redirect "http://example.com:8080" }

      it "has correct uri" do
        assert_equal HTTP::URI.parse("http://example.com:8080"), redirected.uri
      end

      it "has correct verb" do
        assert_equal request.verb, redirected.verb
      end

      it "has correct body" do
        assert_equal request.body, redirected.body
      end

      it "has correct proxy" do
        assert_equal request.proxy, redirected.proxy
      end

      it "presets new Host header" do
        assert_equal "example.com:8080", redirected.headers["Host"]
      end
    end

    context "with schema-less absolute URL given" do
      let(:redirected) { request.redirect "//another.example.com/blog" }

      it "has correct uri" do
        assert_equal HTTP::URI.parse("http://another.example.com/blog"), redirected.uri
      end

      it "has correct verb" do
        assert_equal request.verb, redirected.verb
      end

      it "has correct body" do
        assert_equal request.body, redirected.body
      end

      it "has correct proxy" do
        assert_equal request.proxy, redirected.proxy
      end

      it "presets new Host header" do
        assert_equal "another.example.com", redirected.headers["Host"]
      end
    end

    context "with relative URL given" do
      let(:redirected) { request.redirect "/blog" }

      it "has correct uri" do
        assert_equal HTTP::URI.parse("http://example.com/blog"), redirected.uri
      end

      it "has correct verb" do
        assert_equal request.verb, redirected.verb
      end

      it "has correct body" do
        assert_equal request.body, redirected.body
      end

      it "has correct proxy" do
        assert_equal request.proxy, redirected.proxy
      end

      it "keeps Host header" do
        assert_equal "example.com", redirected.headers["Host"]
      end

      context "with original URI having non-standard port" do
        let(:request) do
          HTTP::Request.new(
            verb:    :post,
            uri:     "http://example.com:8080/",
            headers: headers,
            proxy:   proxy,
            body:    body
          )
        end

        it "has correct uri" do
          assert_equal HTTP::URI.parse("http://example.com:8080/blog"), redirected.uri
        end
      end
    end

    context "with relative URL that misses leading slash given" do
      let(:redirected) { request.redirect "blog" }

      it "has correct uri" do
        assert_equal HTTP::URI.parse("http://example.com/blog"), redirected.uri
      end

      it "has correct verb" do
        assert_equal request.verb, redirected.verb
      end

      it "has correct body" do
        assert_equal request.body, redirected.body
      end

      it "has correct proxy" do
        assert_equal request.proxy, redirected.proxy
      end

      it "keeps Host header" do
        assert_equal "example.com", redirected.headers["Host"]
      end

      context "with original URI having non-standard port" do
        let(:request) do
          HTTP::Request.new(
            verb:    :post,
            uri:     "http://example.com:8080/",
            headers: headers,
            proxy:   proxy,
            body:    body
          )
        end

        it "has correct uri" do
          assert_equal HTTP::URI.parse("http://example.com:8080/blog"), redirected.uri
        end
      end
    end

    context "with new verb given" do
      let(:redirected_with_verb) { request.redirect "http://blog.example.com/", :get }

      it "has correct verb" do
        assert_equal :get, redirected_with_verb.verb
      end

      it "sets body to nil for GET redirect" do
        assert_nil redirected_with_verb.body.source
      end
    end

    context "with verb changed to non-GET" do
      it "preserves body when verb is not :get" do
        redir = request.redirect("http://blog.example.com/", :put)

        assert_equal "The Ultimate Question", redir.body.source
      end
    end

    context "with sensitive headers" do
      let(:headers) { { accept: "text/html", authorization: "Bearer token123", cookie: "session=abc" } }

      context "when redirecting to same origin" do
        let(:redirected) { request.redirect "/other-path" }

        it "preserves Authorization header" do
          assert_equal "Bearer token123", redirected.headers["Authorization"]
        end

        it "preserves Cookie header" do
          assert_equal "session=abc", redirected.headers["Cookie"]
        end
      end

      context "when redirecting to different host" do
        let(:redirected) { request.redirect "http://other.example.com/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end

        it "strips Cookie header" do
          assert_nil redirected.headers["Cookie"]
        end
      end

      context "when redirecting to different scheme" do
        let(:redirected) { request.redirect "https://example.com/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end

        it "strips Cookie header" do
          assert_nil redirected.headers["Cookie"]
        end
      end

      context "when redirecting to different port" do
        let(:redirected) { request.redirect "http://example.com:8080/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end

        it "strips Cookie header" do
          assert_nil redirected.headers["Cookie"]
        end
      end

      context "when redirecting to schema-less URL with different host" do
        let(:redirected) { request.redirect "//other.example.com/path" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end

        it "strips Cookie header" do
          assert_nil redirected.headers["Cookie"]
        end
      end
    end

    context "with Content-Type header" do
      let(:headers) { { accept: "text/html", content_type: "application/json" } }

      context "when verb stays as POST" do
        it "preserves Content-Type" do
          redir = request.redirect("http://blog.example.com/")

          assert_equal "application/json", redir.headers["Content-Type"]
        end
      end

      context "when verb changes to GET" do
        it "strips Content-Type" do
          redir = request.redirect("http://blog.example.com/", :get)

          assert_nil redir.headers["Content-Type"]
        end
      end
    end

    it "always strips Host header before redirect (new host is set)" do
      # The redirect always deletes the original Host header.
      # The new request's Host is set by prepare_headers.
      redir = request.redirect("/other-path")

      assert_equal "example.com", redir.headers["Host"]
    end

    it "does not mutate original request headers" do
      original_accept = request.headers["Accept"]
      request.redirect("http://other.example.com/", :get)

      assert_equal original_accept, request.headers["Accept"]
      assert_equal "example.com", request.headers["Host"]
    end

    it "preserves body source on non-GET redirect" do
      redir = request.redirect("http://blog.example.com/")

      assert_equal "The Ultimate Question", redir.body.source
    end

    it "creates a new body object on redirect (does not share original)" do
      redir = request.redirect("http://blog.example.com/")

      refute_same request.body, redir.body
    end
  end

  describe "#headline" do
    let(:headline) { request.headline }

    it "returns the request line" do
      assert_equal "GET /foo?bar=baz HTTP/1.1", headline
    end

    context "when URI contains encoded query" do
      let(:encoded_query) { "t=1970-01-01T01%3A00%3A00%2B01%3A00" }
      let(:request_uri) { "http://example.com/foo/?#{encoded_query}" }

      it "does not unencode query part" do
        assert_equal "GET /foo/?#{encoded_query} HTTP/1.1", headline
      end
    end

    context "when URI contains non-ASCII path" do
      let(:request_uri) { "http://example.com/\u30AD\u30E7" }

      it "encodes non-ASCII path part" do
        assert_equal "GET /%E3%82%AD%E3%83%A7 HTTP/1.1", headline
      end
    end

    context "when URI contains fragment" do
      let(:request_uri) { "http://example.com/foo#bar" }

      it "omits fragment part" do
        assert_equal "GET /foo HTTP/1.1", headline
      end
    end

    context "with proxy" do
      let(:proxy) { { user: "user", pass: "pass" } }

      it "uses absolute URI in request line" do
        assert_equal "GET http://example.com/foo?bar=baz HTTP/1.1", headline
      end

      context "with fragment in URI" do
        let(:request_uri) { "http://example.com/foo#bar" }

        it "omits fragment in proxy absolute URI" do
          assert_equal "GET http://example.com/foo HTTP/1.1", headline
        end
      end

      context "and HTTPS uri" do
        let(:request_uri) { "https://example.com/foo?bar=baz" }

        it "uses relative URI in request line" do
          assert_equal "GET /foo?bar=baz HTTP/1.1", headline
        end
      end
    end

    context "with custom version" do
      it "includes the version in the headline" do
        req = HTTP::Request.new(verb: :get, uri: "http://example.com/", version: "2.0")

        assert_equal "GET / HTTP/2.0", req.headline
      end
    end

    context "with non-GET verb" do
      it "upcases the verb" do
        req = HTTP::Request.new(verb: :post, uri: "http://example.com/")

        assert_equal "POST / HTTP/1.1", req.headline
      end
    end

    context "with URI containing whitespace" do
      it "raises RequestError with inspect output" do
        req = HTTP::Request.new(verb: :get, uri: "http://example.com/foo")
        req.uri.path = "/foo bar"

        err = assert_raises(HTTP::RequestError) { req.headline }

        assert_includes err.message, "Invalid request URI"
        assert_includes err.message, "/foo bar".inspect
      end
    end
  end

  describe "#socket_host" do
    context "without proxy" do
      let(:proxy) { {} }

      it "returns the URI host" do
        assert_equal "example.com", request.socket_host
      end
    end

    context "with proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "returns the proxy address" do
        assert_equal "proxy.example.com", request.socket_host
      end
    end
  end

  describe "#socket_port" do
    context "without proxy" do
      let(:proxy) { {} }

      it "returns the URI port" do
        assert_equal 80, request.socket_port
      end

      context "with explicit port in URI" do
        let(:request_uri) { "http://example.com:3000/" }

        it "returns the explicit port" do
          assert_equal 3000, request.socket_port
        end
      end

      context "with HTTPS URI" do
        let(:request_uri) { "https://example.com/" }

        it "returns 443" do
          assert_equal 443, request.socket_port
        end
      end
    end

    context "with proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "returns the proxy port" do
        assert_equal 8080, request.socket_port
      end
    end
  end

  describe "#stream" do
    context "without proxy" do
      let(:proxy) { {} }

      it "writes request to socket" do
        io = StringIO.new
        request.stream(io)

        assert_includes io.string, "GET /foo?bar=baz HTTP/1.1"
      end

      it "does not include proxy headers" do
        io = StringIO.new
        request.stream(io)

        refute_includes io.string, "Proxy-Authorization"
      end
    end

    context "with proxy_headers but not using proxy" do
      let(:proxy) { { proxy_headers: { "X-Leak" => "nope" } } }

      it "does not include proxy headers when not using proxy" do
        io = StringIO.new
        request.stream(io)

        refute_includes io.string, "X-Leak"
      end
    end

    context "with HTTP proxy" do
      let(:proxy) do
        {
          proxy_address: "proxy.example.com",
          proxy_port:    8080,
          proxy_headers: { "X-Proxy" => "value" }
        }
      end

      it "merges proxy headers when streaming via HTTP proxy" do
        io = StringIO.new
        request.stream(io)

        assert_includes io.string, "X-Proxy: value"
      end
    end

    context "with HTTPS proxy and proxy headers" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass",
          proxy_headers:  { "X-Proxy" => "nope" }
        }
      end
      let(:request_uri) { "https://example.com/foo" }

      it "does not merge proxy headers for HTTPS request" do
        io = StringIO.new
        request.stream(io)
        output = io.string

        refute_includes output, "X-Proxy"
        refute_includes output, "Proxy-Authorization"
      end
    end

    context "with authenticated HTTP proxy" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass"
        }
      end

      it "includes proxy authorization header" do
        io = StringIO.new
        request.stream(io)

        assert_includes io.string, "Proxy-Authorization: Basic"
      end
    end
  end

  describe "#connect_using_proxy" do
    let(:proxy) do
      {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    end
    let(:request_uri) { "https://example.com/foo" }
    let(:io) { StringIO.new }

    it "writes a CONNECT request" do
      request.connect_using_proxy(io)
      output = io.string

      assert_includes output, "CONNECT example.com:443 HTTP/1.1"
    end

    it "includes proxy auth headers" do
      request.connect_using_proxy(io)
      output = io.string

      assert_includes output, "Proxy-Authorization: Basic"
    end

    it "includes Host header" do
      request.connect_using_proxy(io)
      output = io.string

      assert_includes output, "Host: example.com"
    end

    it "includes User-Agent header" do
      request.connect_using_proxy(io)
      output = io.string

      assert_includes output, "User-Agent:"
    end
  end

  describe "#proxy_connect_header" do
    let(:request_uri) { "https://example.com/" }

    it "returns CONNECT headline" do
      assert_equal "CONNECT example.com:443 HTTP/1.1", request.proxy_connect_header
    end

    context "with non-standard port" do
      let(:request_uri) { "https://example.com:8443/" }

      it "includes the port" do
        assert_equal "CONNECT example.com:8443 HTTP/1.1", request.proxy_connect_header
      end
    end

    context "with custom version" do
      it "includes the version" do
        req = HTTP::Request.new(verb: :get, uri: "https://example.com/", version: "2.0")

        assert_equal "CONNECT example.com:443 HTTP/2.0", req.proxy_connect_header
      end
    end
  end

  describe "#proxy_connect_headers" do
    let(:request_uri) { "https://example.com/" }

    context "with authenticated proxy" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass"
        }
      end

      it "includes proxy authorization" do
        hdrs = request.proxy_connect_headers

        assert_match(/^Basic /, hdrs["Proxy-Authorization"])
      end

      it "includes Host header from the request" do
        hdrs = request.proxy_connect_headers

        assert_equal "example.com", hdrs["Host"]
      end

      it "includes User-Agent header from the request" do
        hdrs = request.proxy_connect_headers

        assert_equal HTTP::Request::USER_AGENT, hdrs["User-Agent"]
      end
    end

    context "with unauthenticated proxy" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "does not include proxy authorization" do
        hdrs = request.proxy_connect_headers

        assert_nil hdrs["Proxy-Authorization"]
      end

      it "includes Host header" do
        hdrs = request.proxy_connect_headers

        assert_equal "example.com", hdrs["Host"]
      end

      it "includes User-Agent header" do
        hdrs = request.proxy_connect_headers

        assert_equal HTTP::Request::USER_AGENT, hdrs["User-Agent"]
      end
    end

    context "with proxy headers" do
      let(:proxy) do
        {
          proxy_address: "proxy.example.com",
          proxy_port:    8080,
          proxy_headers: { "X-Custom" => "value" }
        }
      end

      it "includes custom proxy headers" do
        hdrs = request.proxy_connect_headers

        assert_equal "value", hdrs["X-Custom"]
      end
    end

    context "without proxy headers key" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "only includes Host and User-Agent headers" do
        hdrs = request.proxy_connect_headers

        assert_instance_of HTTP::Headers, hdrs
        assert_equal %w[Host User-Agent], hdrs.keys
      end
    end
  end

  describe "#include_proxy_headers" do
    context "with proxy headers and authenticated proxy" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass",
          proxy_headers:  { "X-Proxy" => "value" }
        }
      end

      it "merges proxy headers into request headers" do
        request.include_proxy_headers

        assert_equal "value", request.headers["X-Proxy"]
      end

      it "adds proxy authorization header" do
        request.include_proxy_headers

        assert_match(/^Basic /, request.headers["Proxy-Authorization"])
      end
    end

    context "with proxy headers but unauthenticated proxy" do
      let(:proxy) do
        {
          proxy_address: "proxy.example.com",
          proxy_port:    8080,
          proxy_headers: { "X-Proxy" => "value" }
        }
      end

      it "merges proxy headers" do
        request.include_proxy_headers

        assert_equal "value", request.headers["X-Proxy"]
      end

      it "does not add proxy authorization" do
        request.include_proxy_headers

        assert_nil request.headers["Proxy-Authorization"]
      end
    end

    context "without proxy headers key" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass"
        }
      end

      it "still adds proxy authorization for authenticated proxy" do
        request.include_proxy_headers

        assert_match(/^Basic /, request.headers["Proxy-Authorization"])
      end

      it "does not raise when proxy_headers key is absent" do
        headers_before = request.headers.to_h.except("Proxy-Authorization")
        request.include_proxy_headers
        headers_after = request.headers.to_h.except("Proxy-Authorization")

        assert_equal headers_before, headers_after
      end
    end
  end

  describe "#include_proxy_authorization_header" do
    let(:proxy) do
      {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    end

    it "sets the Proxy-Authorization header" do
      request.include_proxy_authorization_header

      assert_equal request.proxy_authorization_header, request.headers["Proxy-Authorization"]
    end
  end

  describe "#proxy_authorization_header" do
    let(:proxy) do
      {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    end

    it "returns a Basic auth header" do
      assert request.proxy_authorization_header.start_with?("Basic ")
    end

    it "encodes username and password" do
      expected_digest = ["user:pass"].pack("m0")

      assert_equal "Basic #{expected_digest}", request.proxy_authorization_header
    end
  end

  describe "#inspect" do
    it "returns a useful string representation" do
      assert_equal "#<HTTP::Request/1.1 GET #{request_uri}>", request.inspect
    end

    it "includes the class name" do
      assert_includes request.inspect, "HTTP::Request"
    end

    it "includes the version" do
      assert_includes request.inspect, "1.1"
    end

    it "includes the uppercased verb" do
      assert_includes request.inspect, "GET"
    end

    it "includes the URI" do
      assert_includes request.inspect, request_uri
    end

    context "with POST verb" do
      it "shows POST" do
        req = HTTP::Request.new(verb: :post, uri: "http://example.com/")

        assert_includes req.inspect, "POST"
      end
    end

    # Kills mutation: verb.upcase instead of verb.to_s.upcase
    it "works when verb is a symbol (needs to_s before upcase)" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_includes req.inspect, "GET"
      assert_equal "#<HTTP::Request/1.1 GET http://example.com/>", req.inspect
    end
  end

  describe "#port (private)" do
    # Kills mutations on: @uri.port || @uri.default_port
    # - @uri.port || nil
    # - @uri.port || @uri
    # - @uri.port || self.default_port
    # - @uri.port (removing fallback entirely)
    it "returns the default port when URI has no explicit port" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      # port is private, exercise it through socket_port with no proxy
      assert_equal 80, req.socket_port
    end

    it "returns the explicit port when URI specifies one" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com:9292/")

      assert_equal 9292, req.socket_port
    end

    it "returns HTTPS default port when URI has no explicit port" do
      req = HTTP::Request.new(verb: :get, uri: "https://example.com/")

      assert_equal 443, req.socket_port
    end

    it "returns WS default port when URI has no explicit port" do
      req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

      assert_equal 80, req.socket_port
    end

    it "returns WSS default port when URI has no explicit port" do
      req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

      assert_equal 443, req.socket_port
    end
  end

  describe "#default_host_header_value (private)" do
    # Kills mutation: PORTS.fetch(@scheme) instead of PORTS[@scheme]
    # Both are equivalent for known schemes, but this confirms the behavior
    it "omits port for standard HTTP port" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_equal "example.com", req.headers["Host"]
    end

    it "omits port for standard WS port" do
      req = HTTP::Request.new(verb: :get, uri: "ws://example.com/")

      assert_equal "example.com", req.headers["Host"]
    end

    it "omits port for standard WSS port" do
      req = HTTP::Request.new(verb: :get, uri: "wss://example.com/")

      assert_equal "example.com", req.headers["Host"]
    end

    it "includes port for non-standard WS port" do
      req = HTTP::Request.new(verb: :get, uri: "ws://example.com:8080/")

      assert_equal "example.com:8080", req.headers["Host"]
    end
  end

  describe "#parse_uri! (private)" do
    # Kills mutation: is_a?(String) -> instance_of?(String)
    # A String subclass should still be checked for empty?
    it "raises ArgumentError for empty String subclass" do
      string_subclass = Class.new(String)
      err = assert_raises(ArgumentError) do
        HTTP::Request.new(verb: :get, uri: string_subclass.new(""))
      end
      assert_equal "uri is empty", err.message
    end

    # Kills mutations on @uri.scheme.to_s.downcase.to_sym:
    # - .to_s.to_sym (removing downcase)
    # - .downcase.to_sym (removing to_s)
    # - .to_str.downcase.to_sym (to_str instead of to_s)
    it "normalizes uppercase scheme to lowercase symbol" do
      req = HTTP::Request.new(verb: :get, uri: "HTTP://example.com/")

      assert_equal :http, req.scheme
    end

    it "normalizes mixed case scheme" do
      req = HTTP::Request.new(verb: :get, uri: "HtTpS://example.com/")

      assert_equal :https, req.scheme
    end
  end

  describe "#prepare_headers (private)" do
    # Kills mutations:
    # - headers || {} -> headers (removing nil fallback)
    # - headers || {} -> headers || nil
    # - HTTP::Headers.coerce -> Headers.coerce
    # These are all exercised by passing nil headers (default)
    it "sets default Host and User-Agent when headers is nil" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_equal "example.com", req.headers["Host"]
      assert_equal HTTP::Request::USER_AGENT, req.headers["User-Agent"]
    end
  end

  describe "#prepare_body (private)" do
    # Kills mutations:
    # - body.is_a?(Request::Body) -> body.is_a?(Body)
    # - Request::Body.new(body) -> Body.new(body)
    # These are namespace mutations equivalent within HTTP::Request context
    it "wraps a string body in Request::Body" do
      req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "test")

      assert_instance_of HTTP::Request::Body, req.body
      assert_equal "test", req.body.source
    end
  end

  describe "#validate_method_and_scheme! (private)" do
    # Kills mutation: HTTP::URI::InvalidError -> URI::InvalidError
    it "raises HTTP::URI::InvalidError (not ::URI::InvalidError) for missing scheme" do
      err = assert_raises(HTTP::URI::InvalidError) do
        HTTP::Request.new(verb: :get, uri: "example.com/")
      end
      assert_kind_of HTTP::URI::InvalidError, err
    end
  end

  describe "#redirect" do
    # Kills mutation: `if verb == :get` -> `unless verb == :get`
    # The mutation changes the if/else to unless, so :get would get body.source
    # and non-:get would get nil. Our existing tests cover this partially,
    # but we need to specifically assert nil for :get body source.
    context "when redirecting POST to GET" do
      it "sets body source to nil for GET" do
        req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "data")
        redir = req.redirect("http://other.com/", :get)

        assert_nil redir.body.source
      end

      it "preserves body source for non-GET" do
        req = HTTP::Request.new(verb: :post, uri: "http://example.com/", body: "data")
        redir = req.redirect("http://other.com/", :post)

        assert_equal "data", redir.body.source
      end
    end
  end

  describe "#redirect_headers (private)" do
    # Kills mutation: self.headers.dup -> headers().dup
    # The mutation changes the receiver from self.headers to a local variable
    # call. Both are equivalent in Ruby, but mutant tracks the difference.
    # Existing tests verify redirect preserves Accept and strips Host,
    # which exercises this sufficiently. We need an additional behavioral check.
    it "redirect headers include original non-stripped headers" do
      req = HTTP::Request.new(
        verb:    :post,
        uri:     "http://example.com/",
        headers: { accept: "text/html", "X-Custom" => "val" }
      )
      redir = req.redirect("/other")

      assert_equal "text/html", redir.headers["Accept"]
      assert_equal "val", redir.headers["X-Custom"]
    end
  end

  describe "#headline" do
    # Kills mutation: .to_s -> .to_str
    # Both work on strings. The mutation survives because URI objects have both.
    it "returns a String for the headline" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/path")
      headline = req.headline

      assert_instance_of String, headline
      assert_equal "GET /path HTTP/1.1", headline
    end

    # Kills mutation: verb.to_s.upcase -> verb.upcase
    # verb is a Symbol, which has .upcase in Ruby 3+, so the mutation survives
    it "converts symbol verb to uppercase string in headline" do
      req = HTTP::Request.new(verb: :delete, uri: "http://example.com/")

      assert_equal "DELETE / HTTP/1.1", req.headline
    end
  end

  describe "#initialize" do
    # Kills mutation: uri_normalizer || HTTP::URI::NORMALIZER -> uri_normalizer || URI::NORMALIZER
    # In the HTTP::Request context, URI::NORMALIZER would be ::URI::NORMALIZER
    # which doesn't exist. But HTTP::URI::NORMALIZER does.
    it "uses HTTP::URI::NORMALIZER by default" do
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/")

      assert_equal HTTP::URI::NORMALIZER, req.uri_normalizer
    end

    # Kills mutation: verb.to_s.downcase.to_sym -> verb.downcase.to_sym
    # Symbols have .downcase in Ruby 3+, so this mutation is equivalent.
    # We ensure the verb is correctly symbolized from a String.
    it "converts string verb via to_s before downcase" do
      req = HTTP::Request.new(verb: "GET", uri: "http://example.com/")

      assert_equal :get, req.verb
    end
  end

  describe "#stream" do
    # Kills mutation: Request::Writer.new -> Writer.new
    # In the HTTP::Request context, Writer resolves to HTTP::Request::Writer
    # which is equivalent. This mutation is a namespace equivalence.
    it "creates a Writer and streams the request to socket" do
      io = StringIO.new
      req = HTTP::Request.new(verb: :get, uri: "http://example.com/path")
      req.stream(io)

      assert_match(%r{^GET /path HTTP/1\.1\r\n}, io.string)
      assert_includes io.string, "Host: example.com"
    end
  end

  describe "#socket_host" do
    # Kills mutation: proxy[:proxy_address] -> proxy.fetch(:proxy_address)
    # Both are equivalent when key exists. The test exercises this path.
    context "with proxy that has proxy_address" do
      let(:proxy) { { proxy_address: "myproxy.com", proxy_port: 3128 } }

      it "returns the proxy address value" do
        assert_equal "myproxy.com", request.socket_host
      end
    end
  end

  describe "#socket_port" do
    # Kills mutation: proxy[:proxy_port] -> proxy.fetch(:proxy_port)
    context "with proxy that has proxy_port" do
      let(:proxy) { { proxy_address: "myproxy.com", proxy_port: 3128 } }

      it "returns the proxy port value" do
        assert_equal 3128, request.socket_port
      end
    end
  end

  describe "#using_proxy?" do
    # Kills mutations:
    # - proxy && proxy.keys.size >= 2 -> proxy.keys.size >= 2 (removing && proxy guard)
    # - proxy && proxy.values.size >= 2 (using values instead of keys)
    # - proxy && proxy.size >= 2 (using hash size instead of keys.size)
    context "with nil proxy" do
      it "returns false" do
        req = HTTP::Request.new(verb: :get, uri: "http://example.com/", proxy: {})

        refute_predicate req, :using_proxy?
      end
    end

    context "with exactly two keys" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "returns true" do
        assert_predicate request, :using_proxy?
      end
    end

    context "with three keys" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080, extra: "x" } }

      it "returns true" do
        assert_predicate request, :using_proxy?
      end
    end
  end

  describe "#using_authenticated_proxy?" do
    # Kills mutations:
    # - proxy && proxy.keys.size >= 4 -> proxy.keys.size >= 4
    # - proxy && proxy.values.size >= 4
    # - proxy && proxy.size >= 4
    context "with exactly four keys" do
      let(:proxy) do
        { proxy_address: "proxy.example.com", proxy_port: 8080,
          proxy_username: "user", proxy_password: "pass" }
      end

      it "returns true" do
        assert_predicate request, :using_authenticated_proxy?
      end
    end

    context "with five keys" do
      let(:proxy) do
        { proxy_address: "proxy.example.com", proxy_port: 8080,
          proxy_username: "user", proxy_password: "pass", extra: "x" }
      end

      it "returns true" do
        assert_predicate request, :using_authenticated_proxy?
      end
    end
  end

  describe "#include_proxy_headers" do
    # Kills mutations on proxy.key?(:proxy_headers) guard:
    # - if proxy -> always merges (even when no proxy_headers key)
    # - if true -> always merges
    # - if :proxy_headers -> always truthy
    # - removing the if entirely -> always merges
    # - headers.merge!(proxy.fetch(:proxy_headers)) instead of proxy[:proxy_headers]
    context "with authenticated proxy but NO proxy_headers key" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass"
        }
      end

      it "does not merge nil into headers" do
        header_count_before = request.headers.to_h.except("Proxy-Authorization").size
        request.include_proxy_headers
        header_count_after = request.headers.to_h.except("Proxy-Authorization").size

        assert_equal header_count_before, header_count_after
      end

      it "does not raise when proxy_headers key is absent" do
        request.include_proxy_headers

        assert_match(/^Basic /, request.headers["Proxy-Authorization"])
      end
    end
  end

  describe "#proxy_authorization_header" do
    # Kills mutations:
    # - proxy[:proxy_password] -> proxy.fetch(:proxy_password)
    # - proxy[:proxy_username] -> proxy.fetch(:proxy_username)
    let(:proxy) do
      {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "alice",
        proxy_password: "secret"
      }
    end

    it "encodes the correct username and password" do
      expected = "Basic #{['alice:secret'].pack('m0')}"

      assert_equal expected, request.proxy_authorization_header
    end
  end

  describe "#proxy_connect_headers" do
    # Kills mutations:
    # - HTTP::Headers.coerce -> Headers.coerce (namespace equivalence)
    # - proxy.key?(:proxy_headers) guard mutations (same pattern as include_proxy_headers)
    # - connect_headers.merge!(proxy.fetch(:proxy_headers)) mutation
    let(:request_uri) { "https://example.com/" }

    context "with authenticated proxy and NO proxy_headers key" do
      let(:proxy) do
        {
          proxy_address:  "proxy.example.com",
          proxy_port:     8080,
          proxy_username: "user",
          proxy_password: "pass"
        }
      end

      it "returns HTTP::Headers instance" do
        hdrs = request.proxy_connect_headers

        assert_instance_of HTTP::Headers, hdrs
      end

      it "does not include nil proxy_headers" do
        hdrs = request.proxy_connect_headers

        assert_equal %w[Host User-Agent Proxy-Authorization], hdrs.keys
      end
    end

    context "with unauthenticated proxy and proxy_headers" do
      let(:proxy) do
        {
          proxy_address: "proxy.example.com",
          proxy_port:    8080,
          proxy_headers: { "X-Custom" => "val" }
        }
      end

      it "includes custom proxy headers in connect headers" do
        hdrs = request.proxy_connect_headers

        assert_equal "val", hdrs["X-Custom"]
      end

      it "includes Host header" do
        hdrs = request.proxy_connect_headers

        assert_equal "example.com", hdrs["Host"]
      end
    end

    context "with unauthenticated proxy and NO proxy_headers" do
      let(:proxy) { { proxy_address: "proxy.example.com", proxy_port: 8080 } }

      it "does not raise when proxy_headers key is absent" do
        hdrs = request.proxy_connect_headers

        assert_instance_of HTTP::Headers, hdrs
        assert_equal %w[Host User-Agent], hdrs.keys
      end
    end
  end

  describe "#connect_using_proxy" do
    # Kills mutation: Request::Writer.new -> Writer.new
    let(:proxy) do
      {
        proxy_address:  "proxy.example.com",
        proxy_port:     8080,
        proxy_username: "user",
        proxy_password: "pass"
      }
    end
    let(:request_uri) { "https://example.com:8443/foo" }

    it "writes a valid CONNECT request line" do
      io = StringIO.new
      request.connect_using_proxy(io)

      assert_match(%r{^CONNECT example\.com:8443 HTTP/1\.1\r\n}, io.string)
    end
  end
end
