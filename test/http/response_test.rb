# frozen_string_literal: true

require "test_helper"

class HTTPResponseTest < Minitest::Test
  cover "HTTP::Response*"

  def build_response(status: 200, version: "1.1", headers: {}, body: "Hello world!", uri: "http://example.com/", **opts)
    request = opts.delete(:request) || HTTP::Request.new(verb: :get, uri: uri)
    HTTP::Response.new(status: status, version: version, headers: headers, body: body, request: request, **opts)
  end

  # ---------------------------------------------------------------------------
  # #headers
  # ---------------------------------------------------------------------------
  def test_provides_a_headers_accessor
    response = build_response

    assert_kind_of HTTP::Headers, response.headers
  end

  # ---------------------------------------------------------------------------
  # #to_a
  # ---------------------------------------------------------------------------
  def test_to_a_returns_a_rack_like_array
    headers = { "Content-Type" => "text/plain" }
    response = build_response(headers: headers, body: "Hello world")

    assert_equal [200, headers, "Hello world"], response.to_a
  end

  def test_to_a_returns_an_integer_status_code
    headers = { "Content-Type" => "text/plain" }
    response = build_response(headers: headers, body: "Hello world")

    assert_instance_of Integer, response.to_a.fetch(0)
  end

  def test_to_a_returns_a_plain_hash_for_headers
    headers = { "Content-Type" => "text/plain" }
    response = build_response(headers: headers, body: "Hello world")
    result = response.to_a.fetch(1)

    assert_instance_of Hash, result
    refute_instance_of HTTP::Headers, result
  end

  def test_to_a_returns_a_string_for_body
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    headers = { "Content-Type" => "text/plain" }
    conn = fake(sequence_id: 0, readpartial: proc { raise EOFError }, body_completed?: true)
    resp = HTTP::Response.new(status: 200, version: "1.1", headers: headers,
                              connection: conn, request: request)
    result = resp.to_a.fetch(2)

    assert_instance_of String, result
    refute_instance_of HTTP::Response::Body, result
  end

  # ---------------------------------------------------------------------------
  # #deconstruct_keys
  # ---------------------------------------------------------------------------
  def test_deconstruct_keys_returns_all_keys_when_given_nil
    response = build_response
    result = response.deconstruct_keys(nil)

    assert_instance_of HTTP::Response::Status, result[:status]
    assert_equal "1.1", result[:version]
    assert_instance_of HTTP::Headers, result[:headers]
    assert_equal "Hello world!", result[:body]
    assert_equal response.request, result[:request]
    assert_instance_of HTTP::Headers, result[:proxy_headers]
  end

  def test_deconstruct_keys_returns_only_requested_keys
    response = build_response
    result = response.deconstruct_keys(%i[status version])

    assert_equal 2, result.size
    assert_instance_of HTTP::Response::Status, result[:status]
    assert_equal "1.1", result[:version]
  end

  def test_deconstruct_keys_excludes_unrequested_keys
    response = build_response
    result = response.deconstruct_keys([:status])

    refute_includes result.keys, :version
    refute_includes result.keys, :body
  end

  def test_deconstruct_keys_returns_empty_hash_for_empty_keys
    response = build_response

    assert_equal({}, response.deconstruct_keys([]))
  end

  def test_deconstruct_keys_supports_hash_pattern_matching
    response = build_response
    matched = case response
              in { status: HTTP::Response::Status, version: "1.1" }
                true
              else
                false
              end

    assert matched
  end

  # ---------------------------------------------------------------------------
  # #deconstruct
  # ---------------------------------------------------------------------------
  def test_deconstruct_returns_a_rack_like_array
    headers = { "Content-Type" => "text/plain" }
    response = build_response(headers: headers, body: "Hello world")

    assert_equal [200, headers, "Hello world"], response.deconstruct
  end

  def test_deconstruct_supports_array_pattern_matching
    headers = { "Content-Type" => "text/plain" }
    response = build_response(headers: headers, body: "Hello world")
    matched = case response
              in [200, *, String]
                true
              else
                false
              end

    assert matched
  end

  # ---------------------------------------------------------------------------
  # #content_length
  # ---------------------------------------------------------------------------
  def test_content_length_without_header_returns_nil
    response = build_response

    assert_nil response.content_length
  end

  def test_content_length_with_content_length_5_returns_5
    response = build_response(headers: { "Content-Length" => "5" })

    assert_equal 5, response.content_length
  end

  def test_content_length_with_invalid_content_length_returns_nil
    response = build_response(headers: { "Content-Length" => "foo" })

    assert_nil response.content_length
  end

  def test_content_length_with_duplicate_identical_returns_deduplicated_value
    h = HTTP::Headers.new
    h.add("Content-Length", "5")
    h.add("Content-Length", "5")
    response = build_response(headers: h)

    assert_equal 5, response.content_length
  end

  def test_content_length_with_conflicting_values_returns_nil
    h = HTTP::Headers.new
    h.add("Content-Length", "5")
    h.add("Content-Length", "10")
    response = build_response(headers: h)

    assert_nil response.content_length
  end

  def test_content_length_with_transfer_encoding_header_returns_nil
    response = build_response(headers: { "Transfer-Encoding" => "chunked", "Content-Length" => "5" })

    assert_nil response.content_length
  end

  # ---------------------------------------------------------------------------
  # #mime_type
  # ---------------------------------------------------------------------------
  def test_mime_type_without_content_type_returns_nil
    response = build_response(headers: {})

    assert_nil response.mime_type
  end

  def test_mime_type_with_text_html_returns_text_html
    response = build_response(headers: { "Content-Type" => "text/html" })

    assert_equal "text/html", response.mime_type
  end

  def test_mime_type_with_charset_returns_mime_type_only
    response = build_response(headers: { "Content-Type" => "text/html; charset=utf-8" })

    assert_equal "text/html", response.mime_type
  end

  # ---------------------------------------------------------------------------
  # #charset
  # ---------------------------------------------------------------------------
  def test_charset_without_content_type_returns_nil
    response = build_response(headers: {})

    assert_nil response.charset
  end

  def test_charset_with_text_html_no_charset_returns_nil
    response = build_response(headers: { "Content-Type" => "text/html" })

    assert_nil response.charset
  end

  def test_charset_with_charset_utf8_returns_utf8
    response = build_response(headers: { "Content-Type" => "text/html; charset=utf-8" })

    assert_equal "utf-8", response.charset
  end

  # ---------------------------------------------------------------------------
  # #parse
  # ---------------------------------------------------------------------------
  def test_parse_with_known_content_type_returns_parsed_body
    response = build_response(headers: { "Content-Type" => "application/json" }, body: '{"foo":"100%s"}')

    assert_equal({ "foo" => "100%s" }, response.parse)
  end

  def test_parse_with_unknown_content_type_raises_parse_error
    response = build_response(headers: { "Content-Type" => "application/deadbeef" }, body: '{"foo":"100%s"}')

    assert_raises(HTTP::ParseError) { response.parse }
  end

  def test_parse_with_explicit_mime_type_ignores_response_mime_type
    response = build_response(headers: { "Content-Type" => "application/deadbeef" }, body: '{"foo":"100%s"}')

    assert_equal({ "foo" => "100%s" }, response.parse("application/json"))
  end

  def test_parse_supports_mime_type_aliases
    response = build_response(headers: { "Content-Type" => "application/deadbeef" }, body: '{"foo":"100%s"}')

    assert_equal({ "foo" => "100%s" }, response.parse(:json))
  end

  def test_parse_when_underlying_parser_fails_raises_parse_error
    response = build_response(headers: { "Content-Type" => "application/deadbeef" }, body: "")

    assert_raises(HTTP::ParseError) { response.parse }
  end

  def test_parse_when_underlying_parser_fails_preserves_original_error_message
    response = build_response(headers: { "Content-Type" => "application/deadbeef" }, body: "")
    err = assert_raises(HTTP::ParseError) { response.parse }

    assert_includes err.message, "application/deadbeef"
  end

  # ---------------------------------------------------------------------------
  # #flush
  # ---------------------------------------------------------------------------
  def test_flush_returns_response_self_reference
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    mock_body = fake(to_s: "")
    resp = HTTP::Response.new(status: 200, version: "1.1", body: mock_body, request: request)

    assert_same resp, resp.flush
  end

  def test_flush_flushes_body
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
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

  # ---------------------------------------------------------------------------
  # #inspect
  # ---------------------------------------------------------------------------
  def test_inspect_returns_useful_string_representation
    response = build_response(headers: { content_type: "text/plain" }, body: fake(to_s: "foobar"))

    assert_equal "#<HTTP::Response/1.1 200 OK text/plain>", response.inspect
  end

  # ---------------------------------------------------------------------------
  # #cookies
  # ---------------------------------------------------------------------------
  def test_cookies_returns_an_array_of_http_cookie
    cookies = ["a=1", "b=2; domain=example.com", "c=3; domain=bad.org"]
    response = build_response(headers: { "Set-Cookie" => cookies })
    cookie_list = response.cookies

    assert_kind_of Array, cookie_list
    cookie_list.each { |c| assert_kind_of HTTP::Cookie, c }
  end

  def test_cookies_contains_cookies_without_domain_restriction
    cookies = ["a=1", "b=2; domain=example.com", "c=3; domain=bad.org"]
    response = build_response(headers: { "Set-Cookie" => cookies })
    cookie_list = response.cookies

    assert_equal(1, cookie_list.count { |c| "a" == c.name })
  end

  def test_cookies_contains_cookies_limited_to_domain_of_request_uri
    cookies = ["a=1", "b=2; domain=example.com", "c=3; domain=bad.org"]
    response = build_response(headers: { "Set-Cookie" => cookies })
    cookie_list = response.cookies

    assert_equal(1, cookie_list.count { |c| "b" == c.name })
  end

  def test_cookies_does_not_contain_cookies_limited_to_non_requested_uri
    cookies = ["a=1", "b=2; domain=example.com", "c=3; domain=bad.org"]
    response = build_response(headers: { "Set-Cookie" => cookies })
    cookie_list = response.cookies

    assert_equal(0, cookie_list.count { |c| "c" == c.name })
  end

  # ---------------------------------------------------------------------------
  # #connection
  # ---------------------------------------------------------------------------
  def test_connection_returns_connection_object
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    connection = fake
    response = HTTP::Response.new(
      version:    "1.1",
      status:     200,
      connection: connection,
      request:    request
    )

    assert_equal connection, response.connection
  end

  # ---------------------------------------------------------------------------
  # #chunked?
  # ---------------------------------------------------------------------------
  def test_chunked_returns_true_when_encoding_is_chunked
    response = build_response(headers: { "Transfer-Encoding" => "chunked" })

    assert_predicate response, :chunked?
  end

  def test_chunked_returns_false_by_default
    response = build_response

    refute_predicate response, :chunked?
  end

  # ---------------------------------------------------------------------------
  # backwards compatibility with :uri
  # ---------------------------------------------------------------------------
  def test_backwards_compat_with_uri_defaults_uri
    response = HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      uri:     "http://example.com/"
    )

    assert_equal "http://example.com/", response.request.uri.to_s
  end

  def test_backwards_compat_with_uri_defaults_verb_to_get
    response = HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      uri:     "http://example.com/"
    )

    assert_equal :get, response.request.verb
  end

  def test_backwards_compat_with_both_request_and_uri_raises_argument_error
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    err = assert_raises(ArgumentError) do
      HTTP::Response.new(
        status:  200,
        version: "1.1",
        headers: {},
        body:    "Hello world!",
        uri:     "http://example.com/",
        request: request
      )
    end

    assert_includes err.message, ":uri"
  end

  # ---------------------------------------------------------------------------
  # #body encoding
  # ---------------------------------------------------------------------------
  def test_body_with_no_content_type_returns_binary_encoding
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    chunks = ["Hello, ", "World!"]
    connection = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
    response = HTTP::Response.new(
      status: 200, version: "1.1", headers: {},
      request: request, connection: connection
    )

    assert_equal Encoding::BINARY, response.body.to_s.encoding
  end

  def test_body_with_application_json_returns_utf8_encoding
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    chunks = ["Hello, ", "World!"]
    connection = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
    response = HTTP::Response.new(
      status: 200, version: "1.1", headers: { "Content-Type" => "application/json" },
      request: request, connection: connection
    )

    assert_equal Encoding::UTF_8, response.body.to_s.encoding
  end

  def test_body_with_text_html_returns_binary_encoding
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    chunks = ["Hello, ", "World!"]
    connection = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
    response = HTTP::Response.new(
      status: 200, version: "1.1", headers: { "Content-Type" => "text/html" },
      request: request, connection: connection
    )

    assert_equal Encoding::BINARY, response.body.to_s.encoding
  end

  def test_body_with_charset_utf8_uses_charset_for_encoding
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    chunks = ["Hello, ", "World!"]
    connection = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
    response = HTTP::Response.new(
      status: 200, version: "1.1", headers: { "Content-Type" => "text/html; charset=utf-8" },
      request: request, connection: connection
    )

    assert_equal Encoding::UTF_8, response.body.to_s.encoding
  end

  def test_body_with_explicit_encoding_passes_encoding_to_body
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    chunks = ["Hello, ", "World!"]
    conn = fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) },
                body_completed?: proc { chunks.empty? })
    resp = HTTP::Response.new(
      status: 200, version: "1.1", headers: {},
      request: request, connection: conn, encoding: "UTF-8"
    )

    assert_equal Encoding::UTF_8, resp.body.to_s.encoding
  end

  # ---------------------------------------------------------------------------
  # #initialize defaults
  # ---------------------------------------------------------------------------
  def test_initialize_defaults_headers_to_empty
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    resp = HTTP::Response.new(status: 200, version: "1.1", body: "ok", request: request)

    assert_empty resp.headers
  end

  def test_initialize_defaults_proxy_headers_to_empty
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    resp = HTTP::Response.new(status: 200, version: "1.1", body: "ok", request: request)

    assert_empty resp.proxy_headers
  end

  def test_initialize_passes_proxy_headers_through_to_accessor
    request = HTTP::Request.new(verb: :get, uri: "http://example.com/")
    resp = HTTP::Response.new(
      status: 200, version: "1.1", body: "ok", request: request,
      proxy_headers: { "Via" => "1.1 proxy" }
    )

    assert_equal "1.1 proxy", resp.proxy_headers["Via"]
  end
end
