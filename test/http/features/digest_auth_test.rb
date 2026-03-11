# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::DigestAuth do
  cover "HTTP::Features::DigestAuth*"

  let(:feature) { HTTP::Features::DigestAuth.new(user: "admin", pass: "secret") }
  let(:connection) { fake }

  let(:request) do
    HTTP::Request.new(
      verb:    :get,
      uri:     "https://example.com/protected",
      headers: { "Accept" => "text/html" }
    )
  end

  def build_response(status:, headers: {})
    HTTP::Response.new(
      version: "1.1",
      status:  status,
      headers: headers,
      body:    "",
      request: request
    )
  end

  describe "#around_request" do
    context "when response is not 401" do
      it "returns the response unchanged" do
        response = build_response(status: 200)

        result = feature.around_request(request) { response }

        assert_same response, result
      end
    end

    context "when 401 without WWW-Authenticate header" do
      it "returns the response unchanged" do
        response = build_response(status: 401)

        result = feature.around_request(request) { response }

        assert_same response, result
      end
    end

    context "when 401 with Basic WWW-Authenticate" do
      it "returns the response unchanged" do
        response = build_response(
          status:  401,
          headers: { "WWW-Authenticate" => "Basic realm=\"test\"" }
        )

        result = feature.around_request(request) { response }

        assert_same response, result
      end
    end

    context "when 401 with Digest challenge" do
      let(:challenge_header) do
        'Digest realm="testrealm", nonce="abc123", qop="auth", opaque="xyz789"'
      end

      let(:challenge_response) do
        build_response(
          status:  401,
          headers: { "WWW-Authenticate" => challenge_header }
        )
      end

      it "retries with digest authorization" do
        calls = []
        feature.around_request(request) do |req|
          calls << req
          calls.length == 1 ? challenge_response : build_response(status: 200)
        end

        assert_equal 2, calls.length
        assert_nil calls[0].headers["Authorization"]
        assert_includes calls[1].headers["Authorization"], "Digest "
      end

      it "returns the retried response" do
        ok_response = build_response(status: 200)

        call_count = 0
        result = feature.around_request(request) do |_req|
          call_count += 1
          call_count == 1 ? challenge_response : ok_response
        end

        assert_same ok_response, result
      end

      it "preserves original request headers" do
        retried_request = nil
        call_count = 0

        feature.around_request(request) do |req|
          call_count += 1
          if call_count == 1
            challenge_response
          else
            retried_request = req
            build_response(status: 200)
          end
        end

        assert_equal "text/html", retried_request.headers["Accept"]
      end

      it "preserves original request verb" do
        post_request = HTTP::Request.new(
          verb: :post,
          uri:  "https://example.com/protected",
          body: "data"
        )

        retried_request = nil
        call_count = 0

        feature.around_request(post_request) do |req|
          call_count += 1
          if call_count == 1
            HTTP::Response.new(
              version: "1.1", status: 401, body: "",
              headers: { "WWW-Authenticate" => challenge_header },
              request: post_request
            )
          else
            retried_request = req
            build_response(status: 200)
          end
        end

        assert_equal :post, retried_request.verb
      end
    end
  end

  describe "digest computation" do
    # Test vectors from RFC 2617 Section 3.5
    let(:rfc_feature) { HTTP::Features::DigestAuth.new(user: "Mufasa", pass: "Circle Of Life") }

    let(:rfc_challenge) do
      'Digest realm="testrealm@host.com", qop="auth", ' \
        'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", ' \
        'opaque="5ccc069c403ebaf9f0171e9517f40e41"'
    end

    let(:rfc_request) do
      HTTP::Request.new(verb: :get, uri: "http://www.nowhere.org/dir/index.html")
    end

    let(:rfc_response) do
      HTTP::Response.new(
        version: "1.1", status: 401, body: "",
        headers: { "WWW-Authenticate" => rfc_challenge },
        request: rfc_request
      )
    end

    it "produces correct HA1 for MD5" do
      # MD5("Mufasa:testrealm@host.com:Circle Of Life")
      expected = "939e7578ed9e3c518a452acee763bce9"

      ha1 = rfc_feature.send(:compute_ha1, "MD5", "testrealm@host.com",
                             "dcd98b7102dd2f0e8b11d0f600bfb0c093", "0a4f113b")

      assert_equal expected, ha1
    end

    it "produces correct HA2 for MD5" do
      # MD5("GET:/dir/index.html")
      expected = "39aff3a2bab6126f332b942af96d3366"

      ha2 = rfc_feature.send(:compute_ha2, "MD5", "GET", "/dir/index.html")

      assert_equal expected, ha2
    end

    it "produces correct response with qop=auth" do
      ha1 = "939e7578ed9e3c518a452acee763bce9"
      ha2 = "39aff3a2bab6126f332b942af96d3366"

      expected = "6629fae49393a05397450978507c4ef1"

      result = rfc_feature.send(:compute_response, "MD5", ha1, ha2,
                                nonce: "dcd98b7102dd2f0e8b11d0f600bfb0c093",
                                nonce_count: "00000001", cnonce: "0a4f113b", qop: "auth")

      assert_equal expected, result
    end

    it "includes all required fields in authorization header" do
      retried_request = nil
      call_count = 0

      rfc_feature.around_request(rfc_request) do |req|
        call_count += 1
        if call_count == 1
          rfc_response
        else
          retried_request = req
          HTTP::Response.new(version: "1.1", status: 200, body: "", request: rfc_request)
        end
      end

      auth = retried_request.headers["Authorization"]

      assert_includes auth, 'username="Mufasa"'
      assert_includes auth, 'realm="testrealm@host.com"'
      assert_includes auth, 'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093"'
      assert_includes auth, 'uri="/dir/index.html"'
      assert_includes auth, "qop=auth"
      assert_includes auth, "nc=00000001"
      assert_match(/cnonce="[0-9a-f]+"/, auth)
      assert_match(/response="[0-9a-f]+"/, auth)
      assert_includes auth, 'opaque="5ccc069c403ebaf9f0171e9517f40e41"'
      assert_includes auth, "algorithm=MD5"
    end
  end

  describe "algorithm support" do
    it "supports SHA-256" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=SHA-256'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      assert_includes retried_request.headers["Authorization"], "algorithm=SHA-256"
    end

    it "supports MD5-sess" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=MD5-sess, qop="auth"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      assert_includes retried_request.headers["Authorization"], "algorithm=MD5-sess"
    end

    it "supports SHA-256-sess" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=SHA-256-sess, qop="auth"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      assert_includes retried_request.headers["Authorization"], "algorithm=SHA-256-sess"
    end

    it "raises for unsupported algorithm" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=UNSUPPORTED'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      call_count = 0
      assert_raises(KeyError) do
        feature.around_request(request) do |_req|
          call_count += 1
          call_count == 1 ? response : build_response(status: 200)
        end
      end
    end
  end

  describe "qop handling" do
    it "prefers auth when multiple qop values offered" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth-int,auth"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      assert_includes retried_request.headers["Authorization"], "qop=auth"
    end

    it "uses first qop value when auth not available" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth-int"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      assert_includes retried_request.headers["Authorization"], "qop=auth-int"
    end

    it "omits qop fields when server does not specify qop" do
      challenge = 'Digest realm="test", nonce="abc"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      auth = retried_request.headers["Authorization"]

      refute_includes auth, "qop="
      refute_includes auth, "nc="
      refute_includes auth, "cnonce="
    end

    it "computes response without qop correctly" do
      # Without qop: response = MD5(HA1:nonce:HA2)
      ha1 = "ha1value"
      ha2 = "ha2value"

      expected = Digest::MD5.hexdigest("ha1value:testnonce:ha2value")

      result = feature.send(:compute_response, "MD5", ha1, ha2,
                            nonce: "testnonce", nonce_count: "00000001",
                            cnonce: "cnonce", qop: nil)

      assert_equal expected, result
    end
  end

  describe "opaque handling" do
    it "omits opaque when not in challenge" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth"'
      response = build_response(
        status:  401,
        headers: { "WWW-Authenticate" => challenge }
      )

      retried_request = nil
      call_count = 0

      feature.around_request(request) do |req|
        call_count += 1
        if call_count == 1
          response
        else
          retried_request = req
          build_response(status: 200)
        end
      end

      refute_includes retried_request.headers["Authorization"], "opaque="
    end
  end

  describe "challenge parsing" do
    it "parses quoted values" do
      header = 'Digest realm="test realm", nonce="abc123"'
      result = feature.send(:parse_challenge, header)

      assert_equal "test realm", result["realm"]
      assert_equal "abc123", result["nonce"]
    end

    it "parses unquoted values" do
      header = 'Digest realm="test", algorithm=SHA-256'
      result = feature.send(:parse_challenge, header)

      assert_equal "SHA-256", result["algorithm"]
    end

    it "parses mixed quoted and unquoted values" do
      header = 'Digest realm="test", nonce="n1", qop="auth", algorithm=MD5, opaque="op1"'
      result = feature.send(:parse_challenge, header)

      assert_equal "test", result["realm"]
      assert_equal "n1", result["nonce"]
      assert_equal "auth", result["qop"]
      assert_equal "MD5", result["algorithm"]
      assert_equal "op1", result["opaque"]
    end
  end

  describe "feature registration" do
    it "is registered as :digest_auth" do
      assert_equal HTTP::Features::DigestAuth, HTTP::Options.available_features[:digest_auth]
    end

    it "is a Feature" do
      assert_kind_of HTTP::Feature, feature
    end
  end
end
