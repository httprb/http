# frozen_string_literal: true

require "test_helper"

describe HTTP::Redirector do
  cover "HTTP::Redirector*"
  def simple_response(status, body = "", headers = {})
    HTTP::Response.new(
      status:  status,
      version: "1.1",
      headers: headers,
      body:    body,
      request: HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  def redirect_response(status, location, set_cookie = {})
    res = simple_response status, "", "Location" => location
    set_cookie.each do |name, value|
      res.headers.add("Set-Cookie", "#{name}=#{value}; path=/; httponly; secure; SameSite=none; Secure")
    end
    res
  end

  def cookie_jar_from(redirector)
    redirector.instance_variable_get(:@cookie_jar)
  end

  describe "#strict" do
    context "by default" do
      let(:redirector) { HTTP::Redirector.new }

      it "returns true" do
        assert redirector.strict
      end
    end
  end

  describe "#max_hops" do
    context "by default" do
      let(:redirector) { HTTP::Redirector.new }

      it "returns 5" do
        assert_equal 5, redirector.max_hops
      end
    end

    context "with string value" do
      let(:redirector) { HTTP::Redirector.new(max_hops: "3") }

      it "coerces to integer" do
        assert_equal 3, redirector.max_hops
      end
    end
  end

  describe "#perform" do
    let(:options)    { {} }
    let(:redirector) { HTTP::Redirector.new(options) }

    it "fails with TooManyRedirectsError if max hops reached" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = proc { |prev_req| redirect_response(301, "#{prev_req.uri}/1") }

      assert_raises(HTTP::Redirector::TooManyRedirectsError) do
        redirector.perform(req, res.call(req), &res)
      end
    end

    it "fails with EndlessRedirectError if endless loop detected" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = redirect_response(301, req.uri)

      assert_raises(HTTP::Redirector::EndlessRedirectError) do
        redirector.perform(req, res) { res }
      end
    end

    it "fails with StateError if there were no Location header" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = simple_response(301)

      assert_raises(HTTP::StateError) do
        redirector.perform(req, res) { |_| nil }
      end
    end

    it "returns first non-redirect response" do
      req  = HTTP::Request.new verb: :head, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1"),
        redirect_response(301, "http://example.com/2"),
        redirect_response(301, "http://example.com/3"),
        simple_response(200, "foo"),
        redirect_response(301, "http://example.com/4"),
        simple_response(200, "bar")
      ]

      res = redirector.perform(req, hops.shift) { hops.shift }

      assert_equal "foo", res.to_s
    end

    it "concatenates multiple Location headers" do
      req     = HTTP::Request.new verb: :head, uri: "http://example.com"
      headers = HTTP::Headers.new

      %w[http://example.com /123].each { |loc| headers.add("Location", loc) }

      res = redirector.perform(req, simple_response(301, "", headers)) do |redirect|
        simple_response(200, redirect.uri.to_s)
      end

      assert_equal "http://example.com/123", res.to_s
    end

    it "returns cookies in response" do
      req  = HTTP::Request.new verb: :head, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1", { "foo" => "42" }),
        redirect_response(301, "http://example.com/2", { "bar" => "53", "deleted" => "foo" }),
        redirect_response(301, "http://example.com/3", { "baz" => "64", "deleted" => "" }),
        redirect_response(301, "http://example.com/4", { "baz" => "65" }),
        simple_response(200, "bar")
      ]

      request_cookies = [
        { "foo" => "42" },
        { "foo" => "42", "bar" => "53", "deleted" => "foo" },
        { "foo" => "42", "bar" => "53", "baz" => "64" },
        { "foo" => "42", "bar" => "53", "baz" => "65" }
      ]

      res = redirector.perform(req, hops.shift) do |request|
        req_cookie = HTTP::Cookie.cookie_value_to_hash(request.headers["Cookie"] || "")

        assert_equal request_cookies.shift, req_cookie
        hops.shift
      end

      assert_equal "bar", res.to_s
      assert_equal(
        { "foo" => "42", "bar" => "53", "baz" => "65" },
        res.cookies.cookies.to_h { |c| [c.name, c.value] }
      )
    end

    it "returns original cookies in response" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      req.headers.set("Cookie", "foo=42; deleted=baz")
      hops = [
        redirect_response(301, "http://example.com/1", { "bar" => "64", "deleted" => "" }),
        simple_response(200, "bar")
      ]

      request_cookies = [
        { "foo" => "42", "bar" => "64" },
        { "foo" => "42", "bar" => "64" }
      ]

      res = redirector.perform(req, hops.shift) do |request|
        req_cookie = HTTP::Cookie.cookie_value_to_hash(request.headers["Cookie"] || "")

        assert_equal request_cookies.shift, req_cookie
        hops.shift
      end

      assert_equal "bar", res.to_s
      cookies = res.cookies.cookies.to_h { |c| [c.name, c.value] }

      assert_equal "42", cookies["foo"]
      assert_equal "64", cookies["bar"]
      assert_nil cookies["deleted"]
    end

    it "collects request cookies with correct path" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com/some/path"
      req.headers.set("Cookie", "foo=bar")
      hops = [simple_response(200, "done")]

      redirector.perform(req, redirect_response(301, "http://example.com/other")) do
        hops.shift
      end

      cookie = cookie_jar_from(redirector).detect { |c| c.name == "foo" }

      assert_equal "/some/path", cookie.path
    end

    context "with on_redirect callback" do
      let(:options) do
        {
          on_redirect: proc do |response, location|
            @redirect_response = response
            @redirect_location = location
          end
        }
      end

      it "calls on_redirect" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          redirect_response(301, "http://example.com/2"),
          simple_response(200, "foo")
        ]

        redirector.perform(req, hops.shift) do |prev_req, _|
          assert_equal prev_req.uri.to_s, @redirect_location.uri.to_s
          assert_equal 301, @redirect_response.code
          hops.shift
        end
      end
    end

    # Tests for 300, 301, and 302 share identical behavior:
    # strict mode raises StateError for unsafe verbs, non-strict follows with GET.
    unsafe_verbs = %i[put post delete]

    [300, 301, 302].each do |status_code|
      context "following #{status_code} redirect" do
        context "with strict mode" do
          let(:options) { { strict: true } }

          it "follows with original verb if it's safe" do
            req = HTTP::Request.new verb: :head, uri: "http://example.com"
            res = redirect_response status_code, "http://example.com/1"

            redirector.perform(req, res) do |prev_req, _|
              assert_equal :head, prev_req.verb
              simple_response 200
            end
          end

          unsafe_verbs.each do |verb|
            it "raises StateError if original request was #{verb.upcase}" do
              req = HTTP::Request.new verb: verb, uri: "http://example.com"
              res = redirect_response status_code, "http://example.com/1"

              assert_raises(HTTP::StateError) do
                redirector.perform(req, res) { simple_response 200 }
              end
            end
          end
        end

        context "with non-strict mode" do
          let(:options) { { strict: false } }

          it "follows with original verb if it's safe" do
            req = HTTP::Request.new verb: :head, uri: "http://example.com"
            res = redirect_response status_code, "http://example.com/1"

            redirector.perform(req, res) do |prev_req, _|
              assert_equal :head, prev_req.verb
              simple_response 200
            end
          end

          unsafe_verbs.each do |verb|
            it "follows with GET if original request was #{verb.upcase}" do
              req = HTTP::Request.new verb: verb, uri: "http://example.com"
              res = redirect_response status_code, "http://example.com/1"

              redirector.perform(req, res) do |prev_req, _|
                assert_equal :get, prev_req.verb
                simple_response 200
              end
            end
          end
        end
      end
    end

    context "following 303 redirect" do
      it "follows with HEAD if original request was HEAD" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        res = redirect_response 303, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :head, prev_req.verb
          simple_response 200
        end
      end

      it "follows with GET if original request was GET" do
        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        res = redirect_response 303, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :get, prev_req.verb
          simple_response 200
        end
      end

      it "follows with GET if original request was neither GET nor HEAD" do
        req = HTTP::Request.new verb: :post, uri: "http://example.com"
        res = redirect_response 303, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :get, prev_req.verb
          simple_response 200
        end
      end
    end

    context "following 307 redirect" do
      it "follows with original request's verb" do
        req = HTTP::Request.new verb: :post, uri: "http://example.com"
        res = redirect_response 307, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :post, prev_req.verb
          simple_response 200
        end
      end
    end

    context "following 308 redirect" do
      it "follows with original request's verb" do
        req = HTTP::Request.new verb: :post, uri: "http://example.com"
        res = redirect_response 308, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :post, prev_req.verb
          simple_response 200
        end
      end
    end

    describe "changing verbs during redirects" do
      let(:options) { { strict: false } }
      let(:post_body) { HTTP::Request::Body.new("i might be way longer in real life") }
      let(:cookie) { "dont=eat my cookies" }

      def a_dangerous_request(verb)
        HTTP::Request.new(
          verb: verb, uri: "http://example.com",
          body: post_body, headers: {
            "Content-Type" => "meme",
            "Cookie"       => cookie
          }
        )
      end

      def empty_body
        HTTP::Request::Body.new(nil)
      end

      it "follows without body/content type if it has to change verb" do
        req = a_dangerous_request(:post)
        res = redirect_response 302, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal empty_body, prev_req.body
          assert_equal cookie, prev_req.headers["Cookie"]
          assert_nil prev_req.headers["Content-Type"]
          simple_response 200
        end
      end

      it "leaves body/content-type intact if it does not have to change verb" do
        req = a_dangerous_request(:post)
        res = redirect_response 307, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal post_body, prev_req.body
          assert_equal cookie, prev_req.headers["Cookie"]
          assert_equal "meme", prev_req.headers["Content-Type"]
          simple_response 200
        end
      end
    end

    context "with max_hops: 0" do
      let(:options) { { max_hops: 0 } }

      it "does not limit redirects (unlimited hops)" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        hops = (1..10).map { |i| redirect_response(301, "http://example.com/#{i}") }
        hops << simple_response(200, "done")

        res = redirector.perform(req, hops.shift) { hops.shift }

        assert_equal "done", res.to_s
      end
    end

    context "with max_hops: 1" do
      let(:options) { { max_hops: 1 } }

      it "allows exactly one redirect" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          simple_response(200, "one hop")
        ]

        res = redirector.perform(req, hops.shift) { hops.shift }

        assert_equal "one hop", res.to_s
      end

      it "raises TooManyRedirectsError on the second redirect" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          redirect_response(301, "http://example.com/2"),
          simple_response(200, "unreachable")
        ]

        assert_raises(HTTP::Redirector::TooManyRedirectsError) do
          redirector.perform(req, hops.shift) { hops.shift }
        end
      end
    end

    context "with :get verb on strict-sensitive codes" do
      let(:options) { { strict: true } }

      [300, 301, 302].each do |status_code|
        it "follows #{status_code} redirect with :get verb without raising" do
          req = HTTP::Request.new verb: :get, uri: "http://example.com"
          res = redirect_response status_code, "http://example.com/1"

          result = redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200, "ok"
          end

          assert_equal "ok", result.to_s
        end
      end
    end

    context "following 303 redirect with unsafe verbs" do
      it "follows with GET if original request was PUT" do
        req = HTTP::Request.new verb: :put, uri: "http://example.com"
        res = redirect_response 303, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :get, prev_req.verb
          simple_response 200
        end
      end

      it "follows with GET if original request was DELETE" do
        req = HTTP::Request.new verb: :delete, uri: "http://example.com"
        res = redirect_response 303, "http://example.com/1"

        redirector.perform(req, res) do |prev_req, _|
          assert_equal :get, prev_req.verb
          simple_response 200
        end
      end
    end

    context "on_redirect callback behavior" do
      it "passes both response and request to on_redirect" do
        captured_response = nil
        captured_request = nil
        opts = {
          on_redirect: proc do |response, request|
            captured_response = response
            captured_request = request
          end
        }
        redirector = HTTP::Redirector.new(opts)

        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          simple_response(200, "done")
        ]

        redirector.perform(req, hops.shift) { hops.shift }

        refute_nil captured_response
        refute_nil captured_request
        assert_equal 301, captured_response.code
        assert_equal "http://example.com/1", captured_request.uri.to_s
      end

      it "works without on_redirect callback (default nil)" do
        redirector = HTTP::Redirector.new

        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          simple_response(200, "done")
        ]

        res = redirector.perform(req, hops.shift) { hops.shift }

        assert_equal "done", res.to_s
      end

      it "works when on_redirect is explicitly nil" do
        redirector = HTTP::Redirector.new(on_redirect: nil)

        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        hops = [
          redirect_response(301, "http://example.com/1"),
          simple_response(200, "done")
        ]

        res = redirector.perform(req, hops.shift) { hops.shift }

        assert_equal "done", res.to_s
      end
    end

    it "yields the request to the block" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1"),
        simple_response(200, "done")
      ]

      yielded_request = nil
      redirector.perform(req, hops.shift) do |r|
        yielded_request = r
        hops.shift
      end

      refute_nil yielded_request
      assert_equal "http://example.com/1", yielded_request.uri.to_s
    end

    it "calls flush on intermediate redirect responses" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      res = redirect_response(301, "http://example.com/1")

      flushed = false
      original_flush = res.method(:flush)
      res.define_singleton_method(:flush) do
        flushed = true
        original_flush.call
      end

      redirector.perform(req, res) { simple_response(200, "done") }

      assert flushed, "expected response.flush to be called during redirect"
    end

    it "tracks visited URLs with verb and URI" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      # This request visits the same URL twice, triggering EndlessRedirectError
      res = redirect_response(301, "http://example.com")

      err = assert_raises(HTTP::Redirector::EndlessRedirectError) do
        redirector.perform(req, res) { redirect_response(301, "http://example.com") }
      end
      assert_kind_of HTTP::Redirector::TooManyRedirectsError, err
    end

    it "raises StateError with descriptive message when no Location header" do
      req = HTTP::Request.new verb: :head, uri: "http://example.com"
      res = simple_response(301)

      err = assert_raises(HTTP::StateError) do
        redirector.perform(req, res) { |_| nil }
      end
      assert_match(/no Location header/, err.message)
    end

    context "strict mode StateError messages" do
      let(:options) { { strict: true } }

      it "includes status in the error message" do
        req = HTTP::Request.new verb: :post, uri: "http://example.com"
        res = redirect_response 301, "http://example.com/1"

        err = assert_raises(HTTP::StateError) do
          redirector.perform(req, res) { simple_response 200 }
        end
        assert_match(/301/, err.message)
      end
    end

    it "collects cookies from initial request headers" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      req.headers.set("Cookie", "initial=cookie")
      hops = [
        redirect_response(301, "http://example.com/1"),
        simple_response(200, "done")
      ]

      redirector.perform(req, hops.shift) do |request|
        cookie_header = request.headers["Cookie"]

        assert_includes cookie_header, "initial=cookie"
        hops.shift
      end
    end

    it "collects cookies from response Set-Cookie headers" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1", { "resp_cookie" => "value1" }),
        simple_response(200, "done")
      ]

      redirector.perform(req, hops.shift) do |request|
        cookie_header = request.headers["Cookie"]

        assert_includes cookie_header, "resp_cookie=value1"
        hops.shift
      end
    end

    it "deletes cookies with empty value from final response" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1", { "mycookie" => "present" }),
        redirect_response(301, "http://example.com/2", { "mycookie" => "" }),
        simple_response(200, "done")
      ]

      res = redirector.perform(req, hops.shift) { hops.shift }
      cookie_names = res.cookies.cookies.map(&:name)

      # The cookie with empty value should have been deleted from the jar
      refute_includes cookie_names, "mycookie"
    end

    it "does not set Cookie header when cookie jar is empty" do
      req = HTTP::Request.new verb: :get, uri: "http://example.com"
      hops = [
        redirect_response(301, "http://example.com/1"),
        simple_response(200, "done")
      ]

      redirector.perform(req, hops.shift) do |request|
        assert_nil request.headers["Cookie"]
        hops.shift
      end
    end

    context "with max_hops: 2 and an endless redirect loop" do
      let(:options) { { max_hops: 2 } }

      it "detects the endless loop before reaching max hops" do
        req = HTTP::Request.new verb: :head, uri: "http://example.com"
        res = redirect_response(301, "http://example.com")

        assert_raises(HTTP::Redirector::EndlessRedirectError) do
          redirector.perform(req, res) { redirect_response(301, "http://example.com") }
        end
      end
    end

    context "with Authorization header" do
      it "preserves Authorization when redirecting to same origin" do
        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        req.headers.set("Authorization", "Bearer secret")
        hops = [
          redirect_response(301, "http://example.com/other"),
          simple_response(200, "done")
        ]

        redirector.perform(req, hops.shift) do |request|
          assert_equal "Bearer secret", request.headers["Authorization"]
          hops.shift
        end
      end

      it "strips Authorization when redirecting to different host" do
        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        req.headers.set("Authorization", "Bearer secret")
        hops = [
          redirect_response(301, "http://other.example.com/"),
          simple_response(200, "done")
        ]

        redirector.perform(req, hops.shift) do |request|
          assert_nil request.headers["Authorization"]
          hops.shift
        end
      end

      it "strips Authorization when redirecting to different scheme" do
        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        req.headers.set("Authorization", "Bearer secret")
        hops = [
          redirect_response(301, "https://example.com/"),
          simple_response(200, "done")
        ]

        redirector.perform(req, hops.shift) do |request|
          assert_nil request.headers["Authorization"]
          hops.shift
        end
      end

      it "strips Authorization when redirecting to different port" do
        req = HTTP::Request.new verb: :get, uri: "http://example.com"
        req.headers.set("Authorization", "Bearer secret")
        hops = [
          redirect_response(301, "http://example.com:8080/"),
          simple_response(200, "done")
        ]

        redirector.perform(req, hops.shift) do |request|
          assert_nil request.headers["Authorization"]
          hops.shift
        end
      end
    end

    it "does not falsely detect endless loop when verb changes for same URL" do
      req = HTTP::Request.new verb: :post, uri: "http://example.com"
      # POST http://example.com → 302 → GET http://example.com → 302 → GET http://example.com/done → 200
      # The verb changes from POST to GET on the first redirect.
      # Original code tracks "post http://example.com" then "get http://example.com" (different strings).
      # If verb were nil-ified, both would be " http://example.com" (same string → false loop).
      hops = [
        redirect_response(302, "http://example.com/done"),
        simple_response(200, "done")
      ]

      res = HTTP::Redirector.new(strict: false, max_hops: 5).perform(
        req, redirect_response(302, "http://example.com")
      ) { hops.shift }

      assert_equal "done", res.to_s
    end
  end
end
