# frozen_string_literal: true

require "test_helper"
require "securerandom"

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

  # Helper to perform a digest challenge round-trip and capture the retried request
  def perform_digest_challenge(feat, req, challenge_header) # rubocop:disable Metrics/MethodLength
    retried_request = nil
    call_count = 0

    challenge_resp = HTTP::Response.new(
      version: "1.1", status: 401, body: "",
      headers: { "WWW-Authenticate" => challenge_header },
      request: req
    )

    feat.around_request(req) do |r|
      call_count += 1
      if call_count == 1
        challenge_resp
      else
        retried_request = r
        HTTP::Response.new(version: "1.1", status: 200, body: "", request: req)
      end
    end

    retried_request
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

    context "when 200 with Digest WWW-Authenticate" do
      it "returns the response unchanged (status check matters)" do
        response = build_response(
          status:  200,
          headers: { "WWW-Authenticate" => 'Digest realm="test", nonce="abc"' }
        )

        call_count = 0
        result = feature.around_request(request) do |_req|
          call_count += 1
          response
        end

        assert_same response, result
        assert_equal 1, call_count, "should not retry for non-401 responses"
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

      it "flushes the 401 response body before retrying" do
        flushed = false
        body_mock = Minitest::Mock.new
        body_mock.expect(:to_s, "")

        challenge_response = HTTP::Response.new(
          version: "1.1", status: 401,
          headers: { "WWW-Authenticate" => challenge_header },
          body:    body_mock,
          request: request
        )

        call_count = 0
        feature.around_request(request) do |_req|
          call_count += 1
          if call_count == 1
            challenge_response
          else
            flushed = body_mock.verify
            build_response(status: 200)
          end
        end

        assert flushed, "response body should be flushed (read) before retry"
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

      it "preserves original request body" do
        post_request = HTTP::Request.new(
          verb: :post,
          uri:  "https://example.com/protected",
          body: "request body data"
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

        assert_equal "request body data", retried_request.body.source
      end

      it "preserves original request version" do
        versioned_request = HTTP::Request.new(
          verb:    :get,
          uri:     "https://example.com/protected",
          version: "1.0"
        )

        retried_request = nil
        call_count = 0

        feature.around_request(versioned_request) do |req|
          call_count += 1
          if call_count == 1
            HTTP::Response.new(
              version: "1.0", status: 401, body: "",
              headers: { "WWW-Authenticate" => challenge_header },
              request: versioned_request
            )
          else
            retried_request = req
            build_response(status: 200)
          end
        end

        assert_equal "1.0", retried_request.version
      end

      it "preserves original request uri_normalizer" do
        normalizer = ->(uri) { HTTP::URI::NORMALIZER.call(uri) }
        custom_request = HTTP::Request.new(
          verb:           :get,
          uri:            "https://example.com/protected",
          uri_normalizer: normalizer
        )

        retried_request = nil
        call_count = 0

        feature.around_request(custom_request) do |req|
          call_count += 1
          if call_count == 1
            HTTP::Response.new(
              version: "1.1", status: 401, body: "",
              headers: { "WWW-Authenticate" => challenge_header },
              request: custom_request
            )
          else
            retried_request = req
            build_response(status: 200)
          end
        end

        assert_same normalizer, retried_request.uri_normalizer
      end

      it "preserves original request proxy" do
        proxy_hash = { proxy_address: "proxy.example.com", proxy_port: 8080 }
        proxy_request = HTTP::Request.new(
          verb:  :get,
          uri:   "https://example.com/protected",
          proxy: proxy_hash
        )

        retried_request = nil
        call_count = 0

        feature.around_request(proxy_request) do |req|
          call_count += 1
          if call_count == 1
            HTTP::Response.new(
              version: "1.1", status: 401, body: "",
              headers: { "WWW-Authenticate" => challenge_header },
              request: proxy_request
            )
          else
            retried_request = req
            build_response(status: 200)
          end
        end

        assert_equal proxy_hash, retried_request.proxy
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

    it "produces correct HA1 for MD5-sess" do
      base = Digest::MD5.hexdigest("Mufasa:testrealm@host.com:Circle Of Life")
      expected = Digest::MD5.hexdigest("#{base}:servernonce:clientnonce")

      ha1 = rfc_feature.send(:compute_ha1, "MD5-sess", "testrealm@host.com",
                             "servernonce", "clientnonce")

      assert_equal expected, ha1
    end

    it "produces different HA1 for sess vs non-sess with same inputs" do
      ha1_md5 = rfc_feature.send(:compute_ha1, "MD5", "realm", "nonce", "cnonce")
      ha1_sess = rfc_feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")

      refute_equal ha1_md5, ha1_sess
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
      assert_includes auth, "qop=auth,"
      assert_includes auth, "nc=00000001"
      assert_match(/cnonce="[0-9a-f]{32}"/, auth)
      assert_match(/response="[0-9a-f]{32}"/, auth)
      assert_includes auth, 'opaque="5ccc069c403ebaf9f0171e9517f40e41"'
      assert_includes auth, "algorithm=MD5"
    end

    it "uses correct field ordering in header" do
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

      # Verify ordering: username, realm, nonce, uri, qop, nc, cnonce, response, opaque, algorithm
      username_pos = auth.index("username=")
      realm_pos    = auth.index("realm=")
      nonce_pos    = auth.index("nonce=")
      uri_pos      = auth.index("uri=")
      qop_pos      = auth.index("qop=")
      nc_pos       = auth.index("nc=")
      cnonce_pos   = auth.index("cnonce=")
      response_pos = auth.index("response=")
      opaque_pos   = auth.index("opaque=")
      algo_pos     = auth.index("algorithm=")

      assert_operator username_pos, :<, realm_pos
      assert_operator realm_pos, :<, nonce_pos
      assert_operator nonce_pos, :<, uri_pos
      assert_operator uri_pos, :<, qop_pos
      assert_operator qop_pos, :<, nc_pos
      assert_operator nc_pos, :<, cnonce_pos
      assert_operator cnonce_pos, :<, response_pos
      assert_operator response_pos, :<, opaque_pos
      assert_operator opaque_pos, :<, algo_pos
    end

    it "produces deterministic digest with fixed cnonce" do
      SecureRandom.stub(:hex, "0a4f113b00000000000000000a4f113b") do
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
        ha1 = Digest::MD5.hexdigest("Mufasa:testrealm@host.com:Circle Of Life")
        ha2 = Digest::MD5.hexdigest("GET:/dir/index.html")
        expected_response = Digest::MD5.hexdigest(
          "#{ha1}:dcd98b7102dd2f0e8b11d0f600bfb0c093:00000001:0a4f113b00000000000000000a4f113b:auth:#{ha2}"
        )

        assert_includes auth, %(response="#{expected_response}")
        assert_includes auth, 'cnonce="0a4f113b00000000000000000a4f113b"'
      end
    end
  end

  describe "algorithm support" do
    it "supports SHA-256" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=SHA-256'

      SecureRandom.stub(:hex, "fixed_cnonce_value_xx") do
        retried = perform_digest_challenge(feature, request, challenge)
        auth = retried.headers["Authorization"]

        assert_includes auth, "algorithm=SHA-256"

        ha1 = Digest::SHA256.hexdigest("admin:test:secret")
        ha2 = Digest::SHA256.hexdigest("GET:/protected")
        expected = Digest::SHA256.hexdigest("#{ha1}:abc:#{ha2}")

        assert_includes auth, %(response="#{expected}")
      end
    end

    it "supports MD5-sess" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=MD5-sess, qop="auth"'

      SecureRandom.stub(:hex, "fixedcnonce0000x") do
        retried = perform_digest_challenge(feature, request, challenge)
        auth = retried.headers["Authorization"]

        assert_includes auth, "algorithm=MD5-sess"

        base_ha1 = Digest::MD5.hexdigest("admin:test:secret")
        ha1 = Digest::MD5.hexdigest("#{base_ha1}:abc:fixedcnonce0000x")
        ha2 = Digest::MD5.hexdigest("GET:/protected")
        expected = Digest::MD5.hexdigest("#{ha1}:abc:00000001:fixedcnonce0000x:auth:#{ha2}")

        assert_includes auth, %(response="#{expected}")
      end
    end

    it "supports SHA-256-sess" do
      challenge = 'Digest realm="test", nonce="abc", algorithm=SHA-256-sess, qop="auth"'

      SecureRandom.stub(:hex, "fixedcnonce0000x") do
        retried = perform_digest_challenge(feature, request, challenge)
        auth = retried.headers["Authorization"]

        assert_includes auth, "algorithm=SHA-256-sess"

        base_ha1 = Digest::SHA256.hexdigest("admin:test:secret")
        ha1 = Digest::SHA256.hexdigest("#{base_ha1}:abc:fixedcnonce0000x")
        ha2 = Digest::SHA256.hexdigest("GET:/protected")
        expected = Digest::SHA256.hexdigest("#{ha1}:abc:00000001:fixedcnonce0000x:auth:#{ha2}")

        assert_includes auth, %(response="#{expected}")
      end
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

    it "defaults to MD5 when algorithm not specified" do
      challenge = 'Digest realm="test", nonce="abc"'

      SecureRandom.stub(:hex, "fixedcnonce0000x") do
        retried = perform_digest_challenge(feature, request, challenge)
        auth = retried.headers["Authorization"]

        assert_includes auth, "algorithm=MD5"

        ha1 = Digest::MD5.hexdigest("admin:test:secret")
        ha2 = Digest::MD5.hexdigest("GET:/protected")
        expected = Digest::MD5.hexdigest("#{ha1}:abc:#{ha2}")

        assert_includes auth, %(response="#{expected}")
      end
    end
  end

  describe "qop handling" do
    it "selects auth when auth is present among multiple qop values" do
      result = feature.send(:select_qop, "auth-int,auth")

      assert_equal "auth", result
    end

    it "returns first qop value when auth not available" do
      result = feature.send(:select_qop, "auth-int,other")

      assert_equal "auth-int", result
    end

    it "returns nil when qop_str is nil" do
      result = feature.send(:select_qop, nil)

      assert_nil result
    end

    it "handles spaces around commas in qop" do
      result = feature.send(:select_qop, "auth-int , auth")

      assert_equal "auth", result
    end

    it "handles leading space after comma" do
      result = feature.send(:select_qop, "auth-int, auth")

      assert_equal "auth", result
    end

    it "handles no spaces around comma" do
      result = feature.send(:select_qop, "other,auth")

      assert_equal "auth", result
    end

    it "returns single qop value as-is" do
      result = feature.send(:select_qop, "auth")

      assert_equal "auth", result
    end

    it "strips trailing whitespace from first qop when auth not available" do
      result = feature.send(:select_qop, "auth-int ,other")

      assert_equal "auth-int", result
    end

    it "prefers auth when multiple qop values offered in header" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth-int,auth"'

      retried = perform_digest_challenge(feature, request, challenge)
      auth = retried.headers["Authorization"]

      # Use qop=auth, (with comma) to ensure it's exactly "auth" not "auth-int"
      assert_match(/qop=auth,/, auth)
    end

    it "uses first qop value when auth not available in header" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth-int"'

      retried = perform_digest_challenge(feature, request, challenge)

      assert_match(/qop=auth-int,/, retried.headers["Authorization"])
    end

    it "omits qop fields when server does not specify qop" do
      challenge = 'Digest realm="test", nonce="abc"'

      retried = perform_digest_challenge(feature, request, challenge)
      auth = retried.headers["Authorization"]

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

    it "computes response with qop correctly using all components" do
      ha1 = "ha1hex"
      ha2 = "ha2hex"

      expected = Digest::MD5.hexdigest("ha1hex:nonce1:00000001:cnonce1:auth:ha2hex")

      result = feature.send(:compute_response, "MD5", ha1, ha2,
                            nonce: "nonce1", nonce_count: "00000001",
                            cnonce: "cnonce1", qop: "auth")

      assert_equal expected, result
    end
  end

  describe "opaque handling" do
    it "omits opaque when not in challenge" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth"'

      retried = perform_digest_challenge(feature, request, challenge)

      refute_includes retried.headers["Authorization"], "opaque="
    end

    it "includes opaque when present in challenge" do
      challenge = 'Digest realm="test", nonce="abc", qop="auth", opaque="opq123"'

      retried = perform_digest_challenge(feature, request, challenge)

      assert_includes retried.headers["Authorization"], 'opaque="opq123"'
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

    it "handles empty quoted values" do
      header = 'Digest realm="", nonce="abc"'
      result = feature.send(:parse_challenge, header)

      assert_equal "", result["realm"]
      assert_equal "abc", result["nonce"]
    end

    it "ignores the Digest scheme prefix (no equals sign)" do
      header = 'Digest realm="test", nonce="abc"'
      result = feature.send(:parse_challenge, header)

      assert_nil result["Digest"]
      assert_equal 2, result.size
    end

    it "handles values containing percent characters" do
      header = 'Digest realm="test%20realm", nonce="abc"'
      result = feature.send(:parse_challenge, header)

      assert_equal "test%20realm", result["realm"]
    end
  end

  describe "#hex_digest" do
    it "uses MD5 for MD5 algorithm" do
      expected = Digest::MD5.hexdigest("test_data")
      result = feature.send(:hex_digest, "MD5", "test_data")

      assert_equal expected, result
    end

    it "uses SHA-256 for SHA-256 algorithm" do
      expected = Digest::SHA256.hexdigest("test_data")
      result = feature.send(:hex_digest, "SHA-256", "test_data")

      assert_equal expected, result
    end

    it "strips -sess suffix for algorithm lookup" do
      md5_result = feature.send(:hex_digest, "MD5-sess", "test_data")
      expected = Digest::MD5.hexdigest("test_data")

      assert_equal expected, md5_result
    end

    it "strips -sess suffix case-insensitively" do
      # This test kills the mutation that removes /i flag
      result = feature.send(:hex_digest, "MD5-SESS", "test_data")
      expected = Digest::MD5.hexdigest("test_data")

      assert_equal expected, result
    end

    it "does not match partial -sess in algorithm name" do
      # Ensures the regex is anchored to the end with \z
      assert_raises(KeyError) do
        feature.send(:hex_digest, "-sessMD5", "test_data")
      end
    end
  end

  describe "#compute_ha1" do
    it "returns base HA1 for non-sess algorithms" do
      expected = Digest::MD5.hexdigest("admin:realm:secret")
      result = feature.send(:compute_ha1, "MD5", "realm", "nonce", "cnonce")

      assert_equal expected, result
    end

    it "computes session HA1 for sess algorithms" do
      base = Digest::MD5.hexdigest("admin:realm:secret")
      expected = Digest::MD5.hexdigest("#{base}:servernonce:clientnonce")
      result = feature.send(:compute_ha1, "MD5-sess", "realm", "servernonce", "clientnonce")

      assert_equal expected, result
    end

    it "uses nonce in session HA1 computation" do
      result1 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce1", "cnonce")
      result2 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce2", "cnonce")

      refute_equal result1, result2
    end

    it "uses cnonce in session HA1 computation" do
      result1 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce1")
      result2 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce2")

      refute_equal result1, result2
    end

    it "uses base HA1 in session HA1 computation" do
      feat1 = HTTP::Features::DigestAuth.new(user: "user1", pass: "pass1")
      feat2 = HTTP::Features::DigestAuth.new(user: "user2", pass: "pass2")

      result1 = feat1.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")
      result2 = feat2.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")

      refute_equal result1, result2
    end

    it "computes SHA-256-sess correctly" do
      base = Digest::SHA256.hexdigest("admin:realm:secret")
      expected = Digest::SHA256.hexdigest("#{base}:nonce:cnonce")
      result = feature.send(:compute_ha1, "SHA-256-sess", "realm", "nonce", "cnonce")

      assert_equal expected, result
    end
  end

  describe "#compute_auth_header" do
    it "passes correct ha1 and ha2 to compute_response" do
      # Verify that mutating ha1 or ha2 to nil in compute_auth_header
      # changes the digest response
      ha1 = "correctha1"
      ha2 = "correctha2"
      challenge = { "realm" => "test" }

      result = feature.send(:compute_auth_header,
                            "MD5", "auth", "nonce", "cnonce", "00000001",
                            "/uri", ha1, ha2, challenge)

      expected_response = Digest::MD5.hexdigest("correctha1:nonce:00000001:cnonce:auth:correctha2")

      assert_includes result, %(response="#{expected_response}")
    end

    it "passes nonce to compute_response" do
      ha1 = "ha1val"
      ha2 = "ha2val"
      challenge = { "realm" => "test" }

      result = feature.send(:compute_auth_header,
                            "MD5", "auth", "testnonce", "cnonce", "00000001",
                            "/uri", ha1, ha2, challenge)

      expected_response = Digest::MD5.hexdigest("ha1val:testnonce:00000001:cnonce:auth:ha2val")

      assert_includes result, %(response="#{expected_response}")
    end

    it "passes cnonce to compute_response" do
      ha1 = "ha1val"
      ha2 = "ha2val"
      challenge = { "realm" => "test" }

      result = feature.send(:compute_auth_header,
                            "MD5", "auth", "nonce", "testcnonce", "00000001",
                            "/uri", ha1, ha2, challenge)

      expected_response = Digest::MD5.hexdigest("ha1val:nonce:00000001:testcnonce:auth:ha2val")

      assert_includes result, %(response="#{expected_response}")
    end

    it "passes nonce_count to compute_response" do
      ha1 = "ha1val"
      ha2 = "ha2val"
      challenge = { "realm" => "test" }

      result = feature.send(:compute_auth_header,
                            "MD5", "auth", "nonce", "cnonce", "00000002",
                            "/uri", ha1, ha2, challenge)

      expected_response = Digest::MD5.hexdigest("ha1val:nonce:00000002:cnonce:auth:ha2val")

      assert_includes result, %(response="#{expected_response}")
    end

    it "passes qop to compute_response" do
      ha1 = "ha1val"
      ha2 = "ha2val"
      challenge = { "realm" => "test" }

      result_auth = feature.send(:compute_auth_header,
                                 "MD5", "auth", "nonce", "cnonce", "00000001",
                                 "/uri", ha1, ha2, challenge)

      result_nil = feature.send(:compute_auth_header,
                                "MD5", nil, "nonce", "cnonce", "00000001",
                                "/uri", ha1, ha2, challenge)

      refute_equal result_auth, result_nil
    end
  end

  describe "#build_auth integration" do
    it "uses select_qop to process qop from challenge" do
      # A challenge with "auth-int,auth" should have qop selected as "auth"
      # If select_qop is bypassed (mutation: qop = challenge["qop"]),
      # the raw "auth-int,auth" string would appear in the header
      challenge = 'Digest realm="test", nonce="abc", qop="auth-int,auth"'

      retried = perform_digest_challenge(feature, request, challenge)
      auth = retried.headers["Authorization"]

      # "auth-int,auth" should NOT appear -- select_qop should pick "auth"
      refute_includes auth, "auth-int,auth"
      assert_match(/qop=auth,/, auth)
    end

    it "generates cnonce of correct length" do
      retried = perform_digest_challenge(feature, request,
                                         'Digest realm="test", nonce="abc", qop="auth"')
      auth = retried.headers["Authorization"]

      # SecureRandom.hex(16) produces exactly 32 hex chars
      assert_match(/cnonce="[0-9a-f]{32}"/, auth)
      # Ensure it's exactly 32, not more or less
      cnonce = auth[/cnonce="([0-9a-f]+)"/, 1]

      assert_equal 32, cnonce.length
    end

    it "includes uri from request in header" do
      retried = perform_digest_challenge(feature, request,
                                         'Digest realm="test", nonce="abc"')
      auth = retried.headers["Authorization"]

      assert_includes auth, 'uri="/protected"'
    end

    it "uses request uri in digest computation" do
      # Verify the uri is actually used in the HA2 computation
      req1 = HTTP::Request.new(verb: :get, uri: "https://example.com/path1")
      req2 = HTTP::Request.new(verb: :get, uri: "https://example.com/path2")
      challenge = 'Digest realm="test", nonce="abc"'

      SecureRandom.stub(:hex, "fixedcnonce0000x") do
        retried1 = perform_digest_challenge(feature, req1, challenge)
        retried2 = perform_digest_challenge(feature, req2, challenge)

        resp1 = retried1.headers["Authorization"][/response="([^"]+)"/, 1]
        resp2 = retried2.headers["Authorization"][/response="([^"]+)"/, 1]

        refute_equal resp1, resp2
      end
    end

    it "uses verb in digest computation" do
      get_req = HTTP::Request.new(verb: :get, uri: "https://example.com/protected")
      post_req = HTTP::Request.new(verb: :post, uri: "https://example.com/protected", body: "data")
      challenge = 'Digest realm="test", nonce="abc"'

      SecureRandom.stub(:hex, "fixedcnonce0000x") do
        retried_get = perform_digest_challenge(feature, get_req, challenge)
        retried_post = perform_digest_challenge(feature, post_req, challenge)

        resp_get = retried_get.headers["Authorization"][/response="([^"]+)"/, 1]
        resp_post = retried_post.headers["Authorization"][/response="([^"]+)"/, 1]

        refute_equal resp_get, resp_post
      end
    end
  end

  describe "#build_header" do
    it "formats header with qop fields in correct order" do
      result = feature.send(:build_header,
                            username: "user", realm: "realm", nonce: "nonce",
                            uri: "/path", qop: "auth", nonce_count: "00000001",
                            cnonce: "cn", response: "resp", opaque: "op",
                            algorithm: "MD5")

      expected = 'Digest username="user", realm="realm", nonce="nonce", uri="/path", ' \
                 'qop=auth, nc=00000001, cnonce="cn", response="resp", opaque="op", algorithm=MD5'

      assert_equal expected, result
    end

    it "formats header without qop fields when qop is nil" do
      result = feature.send(:build_header,
                            username: "user", realm: "realm", nonce: "nonce",
                            uri: "/path", qop: nil, nonce_count: "00000001",
                            cnonce: "cn", response: "resp", opaque: nil,
                            algorithm: "MD5")

      expected = 'Digest username="user", realm="realm", nonce="nonce", uri="/path", ' \
                 'response="resp", algorithm=MD5'

      assert_equal expected, result
    end

    it "formats header without opaque when opaque is nil" do
      result = feature.send(:build_header,
                            username: "user", realm: "realm", nonce: "nonce",
                            uri: "/path", qop: "auth", nonce_count: "00000001",
                            cnonce: "cn", response: "resp", opaque: nil,
                            algorithm: "MD5")

      refute_includes result, "opaque="
      assert_includes result, "algorithm=MD5"
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
