# frozen_string_literal: true

require "test_helper"

describe HTTP::Redirector do
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

    context "following 300 redirect" do
      context "with strict mode" do
        let(:options) { { strict: true } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "raises StateError if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end
      end

      context "with non-strict mode" do
        let(:options) { { strict: false } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 300, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end
      end
    end

    context "following 301 redirect" do
      context "with strict mode" do
        let(:options) { { strict: true } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "raises StateError if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end
      end

      context "with non-strict mode" do
        let(:options) { { strict: false } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 301, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end
      end
    end

    context "following 302 redirect" do
      context "with strict mode" do
        let(:options) { { strict: true } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "raises StateError if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end

        it "raises StateError if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          assert_raises(HTTP::StateError) do
            redirector.perform(req, res) { simple_response 200 }
          end
        end
      end

      context "with non-strict mode" do
        let(:options) { { strict: false } }

        it "follows with original verb if it's safe" do
          req = HTTP::Request.new verb: :head, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :head, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was PUT" do
          req = HTTP::Request.new verb: :put, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was POST" do
          req = HTTP::Request.new verb: :post, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
          end
        end

        it "follows with GET if original request was DELETE" do
          req = HTTP::Request.new verb: :delete, uri: "http://example.com"
          res = redirect_response 302, "http://example.com/1"

          redirector.perform(req, res) do |prev_req, _|
            assert_equal :get, prev_req.verb
            simple_response 200
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
  end
end
