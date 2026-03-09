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

  it "provides a #headers accessor" do
    assert_kind_of HTTP::Headers, request.headers
  end

  it "requires URI to have scheme part" do
    assert_raises(HTTP::Request::UnsupportedSchemeError) do
      HTTP::Request.new(verb: :get, uri: "example.com/")
    end
  end

  it "raises UnsupportedMethodError for unknown verbs" do
    err = assert_raises(HTTP::Request::UnsupportedMethodError) do
      HTTP::Request.new(verb: :foobar, uri: "http://example.com/")
    end
    assert_match(/unknown method/, err.message)
  end

  it "provides a #scheme accessor" do
    assert_equal :http, request.scheme
  end

  it "provides a #verb accessor" do
    assert_equal :get, request.verb
  end

  it "sets given headers" do
    assert_equal "text/html", request.headers["Accept"]
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
    end

    context "was explicitly given" do
      before { headers[:host] = "github.com" }

      it "uses the given host" do
        assert_equal "github.com", request.headers["Host"]
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
    end

    context "with Authorization header" do
      let(:headers) { { accept: "text/html", authorization: "Bearer token123" } }

      context "when redirecting to same origin" do
        let(:redirected) { request.redirect "/other-path" }

        it "preserves Authorization header" do
          assert_equal "Bearer token123", redirected.headers["Authorization"]
        end
      end

      context "when redirecting to different host" do
        let(:redirected) { request.redirect "http://other.example.com/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end
      end

      context "when redirecting to different scheme" do
        let(:redirected) { request.redirect "https://example.com/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end
      end

      context "when redirecting to different port" do
        let(:redirected) { request.redirect "http://example.com:8080/" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end
      end

      context "when redirecting to schema-less URL with different host" do
        let(:redirected) { request.redirect "//other.example.com/path" }

        it "strips Authorization header" do
          assert_nil redirected.headers["Authorization"]
        end
      end
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

      context "and HTTPS uri" do
        let(:request_uri) { "https://example.com/foo?bar=baz" }

        it "uses relative URI in request line" do
          assert_equal "GET /foo?bar=baz HTTP/1.1", headline
        end
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

    it "writes a CONNECT request with proxy auth headers" do
      request.connect_using_proxy(io)
      output = io.string

      assert_includes output, "CONNECT example.com:443 HTTP/1.1"
      assert_includes output, "Proxy-Authorization: Basic"
    end
  end

  describe "#proxy_connect_header" do
    let(:request_uri) { "https://example.com/" }

    it "returns CONNECT headline" do
      assert_equal "CONNECT example.com:443 HTTP/1.1", request.send(:proxy_connect_header)
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
        headers = request.send(:proxy_connect_headers)

        assert_match(/^Basic /, headers["Proxy-Authorization"])
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
        headers = request.send(:proxy_connect_headers)

        assert_equal "value", headers["X-Custom"]
      end
    end
  end

  describe "#stream with proxy headers" do
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

  describe "#inspect" do
    it "returns a useful string representation" do
      assert_equal "#<HTTP::Request/1.1 GET #{request_uri}>", request.inspect
    end
  end
end
