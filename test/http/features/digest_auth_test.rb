# frozen_string_literal: true

require "test_helper"
require "securerandom"

class HTTPFeaturesDigestAuthTest < Minitest::Test
  cover "HTTP::Features::DigestAuth*"

  def feature
    @feature ||= HTTP::Features::DigestAuth.new(user: "admin", pass: "secret")
  end

  def connection
    @connection ||= fake
  end

  def request
    @request ||= HTTP::Request.new(
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
  def perform_digest_challenge(feat, req, challenge_header)
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

  def challenge_header
    'Digest realm="testrealm", nonce="abc123", qop="auth", opaque="xyz789"'
  end

  def challenge_response
    build_response(
      status:  401,
      headers: { "WWW-Authenticate" => challenge_header }
    )
  end

  # -- #around_request: when response is not 401 --

  def test_around_request_when_not_401_returns_response_unchanged
    response = build_response(status: 200)
    result = feature.around_request(request) { response }

    assert_same response, result
  end

  # -- #around_request: when 401 without WWW-Authenticate --

  def test_around_request_when_401_without_www_authenticate_returns_response_unchanged
    response = build_response(status: 401)
    result = feature.around_request(request) { response }

    assert_same response, result
  end

  # -- #around_request: when 401 with Basic WWW-Authenticate --

  def test_around_request_when_401_with_basic_returns_response_unchanged
    response = build_response(
      status:  401,
      headers: { "WWW-Authenticate" => "Basic realm=\"test\"" }
    )
    result = feature.around_request(request) { response }

    assert_same response, result
  end

  # -- #around_request: when 200 with Digest WWW-Authenticate --

  def test_around_request_when_200_with_digest_returns_response_unchanged
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

  # -- #around_request: when 401 with Digest challenge --

  def test_around_request_with_digest_challenge_retries_with_digest_authorization
    calls = []
    feature.around_request(request) do |req|
      calls << req
      calls.length == 1 ? challenge_response : build_response(status: 200)
    end

    assert_equal 2, calls.length
    assert_nil calls[0].headers["Authorization"]
    assert_includes calls[1].headers["Authorization"], "Digest "
  end

  def test_around_request_with_digest_challenge_flushes_401_body_before_retrying
    flushed = false
    body_mock = Minitest::Mock.new
    body_mock.expect(:to_s, "")

    challenge_resp = HTTP::Response.new(
      version: "1.1", status: 401,
      headers: { "WWW-Authenticate" => challenge_header },
      body:    body_mock,
      request: request
    )

    call_count = 0
    feature.around_request(request) do |_req|
      call_count += 1
      if call_count == 1
        challenge_resp
      else
        flushed = body_mock.verify
        build_response(status: 200)
      end
    end

    assert flushed, "response body should be flushed (read) before retry"
  end

  def test_around_request_with_digest_challenge_returns_the_retried_response
    ok_response = build_response(status: 200)

    call_count = 0
    result = feature.around_request(request) do |_req|
      call_count += 1
      call_count == 1 ? challenge_response : ok_response
    end

    assert_same ok_response, result
  end

  def test_around_request_with_digest_challenge_preserves_original_request_headers
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

  def test_around_request_with_digest_challenge_preserves_original_request_verb
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

  def test_around_request_with_digest_challenge_preserves_original_request_body
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

  def test_around_request_with_digest_challenge_preserves_original_request_version
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

  def test_around_request_with_digest_challenge_preserves_original_request_uri_normalizer
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

  def test_around_request_with_digest_challenge_preserves_original_request_proxy
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

  # -- digest computation --

  def rfc_feature
    @rfc_feature ||= HTTP::Features::DigestAuth.new(user: "Mufasa", pass: "Circle Of Life")
  end

  def rfc_challenge
    'Digest realm="testrealm@host.com", qop="auth", ' \
      'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", ' \
      'opaque="5ccc069c403ebaf9f0171e9517f40e41"'
  end

  def rfc_request
    @rfc_request ||= HTTP::Request.new(verb: :get, uri: "http://www.nowhere.org/dir/index.html")
  end

  def rfc_response
    HTTP::Response.new(
      version: "1.1", status: 401, body: "",
      headers: { "WWW-Authenticate" => rfc_challenge },
      request: rfc_request
    )
  end

  def test_digest_computation_produces_correct_ha1_for_md5
    expected = "939e7578ed9e3c518a452acee763bce9"
    ha1 = rfc_feature.send(:compute_ha1, "MD5", "testrealm@host.com",
                           "dcd98b7102dd2f0e8b11d0f600bfb0c093", "0a4f113b")

    assert_equal expected, ha1
  end

  def test_digest_computation_produces_correct_ha1_for_md5_sess
    base = Digest::MD5.hexdigest("Mufasa:testrealm@host.com:Circle Of Life")
    expected = Digest::MD5.hexdigest("#{base}:servernonce:clientnonce")
    ha1 = rfc_feature.send(:compute_ha1, "MD5-sess", "testrealm@host.com",
                           "servernonce", "clientnonce")

    assert_equal expected, ha1
  end

  def test_digest_computation_produces_different_ha1_for_sess_vs_non_sess
    ha1_md5 = rfc_feature.send(:compute_ha1, "MD5", "realm", "nonce", "cnonce")
    ha1_sess = rfc_feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")

    refute_equal ha1_md5, ha1_sess
  end

  def test_digest_computation_produces_correct_ha2_for_md5
    expected = "39aff3a2bab6126f332b942af96d3366"
    ha2 = rfc_feature.send(:compute_ha2, "MD5", "GET", "/dir/index.html")

    assert_equal expected, ha2
  end

  def test_digest_computation_produces_correct_response_with_qop_auth
    ha1 = "939e7578ed9e3c518a452acee763bce9"
    ha2 = "39aff3a2bab6126f332b942af96d3366"
    expected = "6629fae49393a05397450978507c4ef1"

    result = rfc_feature.send(:compute_response, "MD5", ha1, ha2,
                              nonce: "dcd98b7102dd2f0e8b11d0f600bfb0c093",
                              nonce_count: "00000001", cnonce: "0a4f113b", qop: "auth")

    assert_equal expected, result
  end

  def test_digest_computation_includes_all_required_fields_in_authorization_header
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

  def test_digest_computation_uses_correct_field_ordering_in_header
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

  def test_digest_computation_produces_deterministic_digest_with_fixed_cnonce
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

  # -- algorithm support --

  def test_algorithm_support_sha256
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

  def test_algorithm_support_md5_sess
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

  def test_algorithm_support_sha256_sess
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

  def test_algorithm_support_raises_for_unsupported_algorithm
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

  def test_algorithm_support_defaults_to_md5_when_algorithm_not_specified
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

  # -- qop handling --

  def test_qop_selects_auth_when_present_among_multiple_values
    result = feature.send(:select_qop, "auth-int,auth")

    assert_equal "auth", result
  end

  def test_qop_returns_first_value_when_auth_not_available
    result = feature.send(:select_qop, "auth-int,other")

    assert_equal "auth-int", result
  end

  def test_qop_returns_nil_when_qop_str_is_nil
    result = feature.send(:select_qop, nil)

    assert_nil result
  end

  def test_qop_handles_spaces_around_commas
    result = feature.send(:select_qop, "auth-int , auth")

    assert_equal "auth", result
  end

  def test_qop_handles_leading_space_after_comma
    result = feature.send(:select_qop, "auth-int, auth")

    assert_equal "auth", result
  end

  def test_qop_handles_no_spaces_around_comma
    result = feature.send(:select_qop, "other,auth")

    assert_equal "auth", result
  end

  def test_qop_returns_single_value_as_is
    result = feature.send(:select_qop, "auth")

    assert_equal "auth", result
  end

  def test_qop_strips_trailing_whitespace_from_first_when_auth_not_available
    result = feature.send(:select_qop, "auth-int ,other")

    assert_equal "auth-int", result
  end

  def test_qop_prefers_auth_when_multiple_values_offered_in_header
    challenge = 'Digest realm="test", nonce="abc", qop="auth-int,auth"'
    retried = perform_digest_challenge(feature, request, challenge)
    auth = retried.headers["Authorization"]

    assert_match(/qop=auth,/, auth)
  end

  def test_qop_uses_first_value_when_auth_not_available_in_header
    challenge = 'Digest realm="test", nonce="abc", qop="auth-int"'
    retried = perform_digest_challenge(feature, request, challenge)

    assert_match(/qop=auth-int,/, retried.headers["Authorization"])
  end

  def test_qop_omits_fields_when_server_does_not_specify_qop
    challenge = 'Digest realm="test", nonce="abc"'
    retried = perform_digest_challenge(feature, request, challenge)
    auth = retried.headers["Authorization"]

    refute_includes auth, "qop="
    refute_includes auth, "nc="
    refute_includes auth, "cnonce="
  end

  def test_qop_computes_response_without_qop_correctly
    ha1 = "ha1value"
    ha2 = "ha2value"
    expected = Digest::MD5.hexdigest("ha1value:testnonce:ha2value")
    result = feature.send(:compute_response, "MD5", ha1, ha2,
                          nonce: "testnonce", nonce_count: "00000001",
                          cnonce: "cnonce", qop: nil)

    assert_equal expected, result
  end

  def test_qop_computes_response_with_qop_correctly_using_all_components
    ha1 = "ha1hex"
    ha2 = "ha2hex"
    expected = Digest::MD5.hexdigest("ha1hex:nonce1:00000001:cnonce1:auth:ha2hex")
    result = feature.send(:compute_response, "MD5", ha1, ha2,
                          nonce: "nonce1", nonce_count: "00000001",
                          cnonce: "cnonce1", qop: "auth")

    assert_equal expected, result
  end

  # -- opaque handling --

  def test_opaque_omits_when_not_in_challenge
    challenge = 'Digest realm="test", nonce="abc", qop="auth"'
    retried = perform_digest_challenge(feature, request, challenge)

    refute_includes retried.headers["Authorization"], "opaque="
  end

  def test_opaque_includes_when_present_in_challenge
    challenge = 'Digest realm="test", nonce="abc", qop="auth", opaque="opq123"'
    retried = perform_digest_challenge(feature, request, challenge)

    assert_includes retried.headers["Authorization"], 'opaque="opq123"'
  end

  # -- challenge parsing --

  def test_challenge_parsing_parses_quoted_values
    header = 'Digest realm="test realm", nonce="abc123"'
    result = feature.send(:parse_challenge, header)

    assert_equal "test realm", result["realm"]
    assert_equal "abc123", result["nonce"]
  end

  def test_challenge_parsing_parses_unquoted_values
    header = 'Digest realm="test", algorithm=SHA-256'
    result = feature.send(:parse_challenge, header)

    assert_equal "SHA-256", result["algorithm"]
  end

  def test_challenge_parsing_parses_mixed_quoted_and_unquoted_values
    header = 'Digest realm="test", nonce="n1", qop="auth", algorithm=MD5, opaque="op1"'
    result = feature.send(:parse_challenge, header)

    assert_equal "test", result["realm"]
    assert_equal "n1", result["nonce"]
    assert_equal "auth", result["qop"]
    assert_equal "MD5", result["algorithm"]
    assert_equal "op1", result["opaque"]
  end

  def test_challenge_parsing_handles_empty_quoted_values
    header = 'Digest realm="", nonce="abc"'
    result = feature.send(:parse_challenge, header)

    assert_equal "", result["realm"]
    assert_equal "abc", result["nonce"]
  end

  def test_challenge_parsing_ignores_digest_scheme_prefix
    header = 'Digest realm="test", nonce="abc"'
    result = feature.send(:parse_challenge, header)

    assert_nil result["Digest"]
    assert_equal 2, result.size
  end

  def test_challenge_parsing_handles_values_containing_percent_characters
    header = 'Digest realm="test%20realm", nonce="abc"'
    result = feature.send(:parse_challenge, header)

    assert_equal "test%20realm", result["realm"]
  end

  # -- #hex_digest --

  def test_hex_digest_uses_md5_for_md5_algorithm
    expected = Digest::MD5.hexdigest("test_data")
    result = feature.send(:hex_digest, "MD5", "test_data")

    assert_equal expected, result
  end

  def test_hex_digest_uses_sha256_for_sha256_algorithm
    expected = Digest::SHA256.hexdigest("test_data")
    result = feature.send(:hex_digest, "SHA-256", "test_data")

    assert_equal expected, result
  end

  def test_hex_digest_strips_sess_suffix_for_algorithm_lookup
    md5_result = feature.send(:hex_digest, "MD5-sess", "test_data")
    expected = Digest::MD5.hexdigest("test_data")

    assert_equal expected, md5_result
  end

  def test_hex_digest_strips_sess_suffix_case_insensitively
    result = feature.send(:hex_digest, "MD5-SESS", "test_data")
    expected = Digest::MD5.hexdigest("test_data")

    assert_equal expected, result
  end

  def test_hex_digest_does_not_match_partial_sess_in_algorithm_name
    assert_raises(KeyError) do
      feature.send(:hex_digest, "-sessMD5", "test_data")
    end
  end

  # -- #compute_ha1 --

  def test_compute_ha1_returns_base_ha1_for_non_sess_algorithms
    expected = Digest::MD5.hexdigest("admin:realm:secret")
    result = feature.send(:compute_ha1, "MD5", "realm", "nonce", "cnonce")

    assert_equal expected, result
  end

  def test_compute_ha1_computes_session_ha1_for_sess_algorithms
    base = Digest::MD5.hexdigest("admin:realm:secret")
    expected = Digest::MD5.hexdigest("#{base}:servernonce:clientnonce")
    result = feature.send(:compute_ha1, "MD5-sess", "realm", "servernonce", "clientnonce")

    assert_equal expected, result
  end

  def test_compute_ha1_uses_nonce_in_session_ha1_computation
    result1 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce1", "cnonce")
    result2 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce2", "cnonce")

    refute_equal result1, result2
  end

  def test_compute_ha1_uses_cnonce_in_session_ha1_computation
    result1 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce1")
    result2 = feature.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce2")

    refute_equal result1, result2
  end

  def test_compute_ha1_uses_base_ha1_in_session_ha1_computation
    feat1 = HTTP::Features::DigestAuth.new(user: "user1", pass: "pass1")
    feat2 = HTTP::Features::DigestAuth.new(user: "user2", pass: "pass2")
    result1 = feat1.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")
    result2 = feat2.send(:compute_ha1, "MD5-sess", "realm", "nonce", "cnonce")

    refute_equal result1, result2
  end

  def test_compute_ha1_computes_sha256_sess_correctly
    base = Digest::SHA256.hexdigest("admin:realm:secret")
    expected = Digest::SHA256.hexdigest("#{base}:nonce:cnonce")
    result = feature.send(:compute_ha1, "SHA-256-sess", "realm", "nonce", "cnonce")

    assert_equal expected, result
  end

  # -- #compute_auth_header --

  def test_compute_auth_header_passes_correct_ha1_and_ha2_to_compute_response
    ha1 = "correctha1"
    ha2 = "correctha2"
    challenge = { "realm" => "test" }
    result = feature.send(:compute_auth_header,
                          algorithm: "MD5", qop: "auth", nonce: "nonce", cnonce: "cnonce",
                          nonce_count: "00000001", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)
    expected_response = Digest::MD5.hexdigest("correctha1:nonce:00000001:cnonce:auth:correctha2")

    assert_includes result, %(response="#{expected_response}")
  end

  def test_compute_auth_header_passes_nonce_to_compute_response
    ha1 = "ha1val"
    ha2 = "ha2val"
    challenge = { "realm" => "test" }
    result = feature.send(:compute_auth_header,
                          algorithm: "MD5", qop: "auth", nonce: "testnonce", cnonce: "cnonce",
                          nonce_count: "00000001", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)
    expected_response = Digest::MD5.hexdigest("ha1val:testnonce:00000001:cnonce:auth:ha2val")

    assert_includes result, %(response="#{expected_response}")
  end

  def test_compute_auth_header_passes_cnonce_to_compute_response
    ha1 = "ha1val"
    ha2 = "ha2val"
    challenge = { "realm" => "test" }
    result = feature.send(:compute_auth_header,
                          algorithm: "MD5", qop: "auth", nonce: "nonce", cnonce: "testcnonce",
                          nonce_count: "00000001", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)
    expected_response = Digest::MD5.hexdigest("ha1val:nonce:00000001:testcnonce:auth:ha2val")

    assert_includes result, %(response="#{expected_response}")
  end

  def test_compute_auth_header_passes_nonce_count_to_compute_response
    ha1 = "ha1val"
    ha2 = "ha2val"
    challenge = { "realm" => "test" }
    result = feature.send(:compute_auth_header,
                          algorithm: "MD5", qop: "auth", nonce: "nonce", cnonce: "cnonce",
                          nonce_count: "00000002", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)
    expected_response = Digest::MD5.hexdigest("ha1val:nonce:00000002:cnonce:auth:ha2val")

    assert_includes result, %(response="#{expected_response}")
  end

  def test_compute_auth_header_passes_qop_to_compute_response
    ha1 = "ha1val"
    ha2 = "ha2val"
    challenge = { "realm" => "test" }

    result_auth = feature.send(:compute_auth_header,
                               algorithm: "MD5", qop: "auth", nonce: "nonce", cnonce: "cnonce",
                               nonce_count: "00000001", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)

    result_nil = feature.send(:compute_auth_header,
                              algorithm: "MD5", qop: nil, nonce: "nonce", cnonce: "cnonce",
                              nonce_count: "00000001", uri: "/uri", ha1: ha1, ha2: ha2, challenge: challenge)

    refute_equal result_auth, result_nil
  end

  # -- #build_auth integration --

  def test_build_auth_uses_select_qop_to_process_qop_from_challenge
    challenge = 'Digest realm="test", nonce="abc", qop="auth-int,auth"'
    retried = perform_digest_challenge(feature, request, challenge)
    auth = retried.headers["Authorization"]

    refute_includes auth, "auth-int,auth"
    assert_match(/qop=auth,/, auth)
  end

  def test_build_auth_generates_cnonce_of_correct_length
    retried = perform_digest_challenge(feature, request,
                                       'Digest realm="test", nonce="abc", qop="auth"')
    auth = retried.headers["Authorization"]

    assert_match(/cnonce="[0-9a-f]{32}"/, auth)
    cnonce = auth[/cnonce="([0-9a-f]+)"/, 1]

    assert_equal 32, cnonce.length
  end

  def test_build_auth_includes_uri_from_request_in_header
    retried = perform_digest_challenge(feature, request,
                                       'Digest realm="test", nonce="abc"')
    auth = retried.headers["Authorization"]

    assert_includes auth, 'uri="/protected"'
  end

  def test_build_auth_uses_request_uri_in_digest_computation
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

  def test_build_auth_uses_verb_in_digest_computation
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

  # -- #build_header --

  def test_build_header_formats_header_with_qop_fields_in_correct_order
    result = feature.send(:build_header,
                          username: "user", realm: "realm", nonce: "nonce",
                          uri: "/path", qop: "auth", nonce_count: "00000001",
                          cnonce: "cn", response: "resp", opaque: "op",
                          algorithm: "MD5")

    expected = 'Digest username="user", realm="realm", nonce="nonce", uri="/path", ' \
               'qop=auth, nc=00000001, cnonce="cn", response="resp", opaque="op", algorithm=MD5'

    assert_equal expected, result
  end

  def test_build_header_formats_header_without_qop_fields_when_qop_is_nil
    result = feature.send(:build_header,
                          username: "user", realm: "realm", nonce: "nonce",
                          uri: "/path", qop: nil, nonce_count: "00000001",
                          cnonce: "cn", response: "resp", opaque: nil,
                          algorithm: "MD5")

    expected = 'Digest username="user", realm="realm", nonce="nonce", uri="/path", ' \
               'response="resp", algorithm=MD5'

    assert_equal expected, result
  end

  def test_build_header_formats_header_without_opaque_when_opaque_is_nil
    result = feature.send(:build_header,
                          username: "user", realm: "realm", nonce: "nonce",
                          uri: "/path", qop: "auth", nonce_count: "00000001",
                          cnonce: "cn", response: "resp", opaque: nil,
                          algorithm: "MD5")

    refute_includes result, "opaque="
    assert_includes result, "algorithm=MD5"
  end

  # -- feature registration --

  def test_feature_registration_is_registered_as_digest_auth
    assert_equal HTTP::Features::DigestAuth, HTTP::Options.available_features[:digest_auth]
  end

  def test_feature_registration_is_a_feature
    assert_kind_of HTTP::Feature, feature
  end
end
