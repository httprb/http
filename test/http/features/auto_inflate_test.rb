# frozen_string_literal: true

require "test_helper"

class HTTPFeaturesAutoInflateTest < Minitest::Test
  cover "HTTP::Features::AutoInflate*"

  def feature
    @feature ||= HTTP::Features::AutoInflate.new
  end

  def connection
    @connection ||= fake
  end

  def proxy_hdrs
    { "Proxy-Connection" => "keep-alive" }
  end

  def build_response(headers: {})
    HTTP::Response.new(
      version:       "1.1",
      status:        200,
      headers:       headers,
      proxy_headers: proxy_hdrs,
      connection:    connection,
      request:       HTTP::Request.new(verb: :get, uri: "http://example.com")
    )
  end

  # -- #wrap_response: no Content-Encoding --

  def test_wrap_response_when_no_content_encoding_returns_original_response
    response = build_response
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_for_identity_content_encoding_returns_original_response
    response = build_response(headers: { content_encoding: "identity" })
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_for_unknown_content_encoding_returns_original_response
    response = build_response(headers: { content_encoding: "not-supported" })
    result = feature.wrap_response(response)

    assert_same response, result
  end

  # -- #wrap_response: deflate --

  def test_wrap_response_for_deflate_returns_a_new_response
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    refute_same response, result
  end

  def test_wrap_response_for_deflate_returns_an_http_response
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_instance_of HTTP::Response, result
  end

  def test_wrap_response_for_deflate_wraps_the_body_with_an_inflating_body
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_instance_of HTTP::Response::Body, result.body
  end

  def test_wrap_response_for_deflate_preserves_the_status
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_equal response.status.code, result.status.code
  end

  def test_wrap_response_for_deflate_preserves_the_version
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_equal response.version, result.version
  end

  def test_wrap_response_for_deflate_preserves_the_headers
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_equal response.headers.to_h, result.headers.to_h
  end

  def test_wrap_response_for_deflate_preserves_the_proxy_headers
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_equal response.proxy_headers.to_h, result.proxy_headers.to_h
    refute_empty result.proxy_headers.to_h
  end

  def test_wrap_response_for_deflate_preserves_the_request
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_equal response.request, result.request
  end

  def test_wrap_response_for_deflate_wraps_body_stream_in_an_inflater
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)
    stream = result.body.instance_variable_get(:@stream)

    assert_instance_of HTTP::Response::Inflater, stream
  end

  def test_wrap_response_for_deflate_passes_original_connection_to_inflater
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)
    stream = result.body.instance_variable_get(:@stream)

    assert_same connection, stream.connection
  end

  def test_wrap_response_for_deflate_preserves_the_connection_on_wrapped_response
    response = build_response(headers: { content_encoding: "deflate" })
    result = feature.wrap_response(response)

    assert_same connection, result.connection
  end

  # -- #wrap_response: gzip --

  def test_wrap_response_for_gzip_returns_a_new_response_wrapping_inflated_body
    response = build_response(headers: { content_encoding: "gzip" })
    result = feature.wrap_response(response)

    refute_same response, result
    assert_instance_of HTTP::Response::Body, result.body
  end

  # -- #wrap_response: x-gzip --

  def test_wrap_response_for_x_gzip_returns_a_new_response_wrapping_inflated_body
    response = build_response(headers: { content_encoding: "x-gzip" })
    result = feature.wrap_response(response)

    refute_same response, result
    assert_instance_of HTTP::Response::Body, result.body
  end

  # -- #wrap_response: gzip with charset --

  def test_wrap_response_for_gzip_with_charset_preserves_encoding
    response = build_response(headers: { content_encoding: "gzip", content_type: "text/html; charset=Shift_JIS" })
    result = feature.wrap_response(response)

    assert_equal Encoding::Shift_JIS, result.body.encoding
  end

  # -- #wrap_response: response with uri --

  def test_wrap_response_preserves_uri_in_wrapped_response
    response = HTTP::Response.new(
      version:    "1.1",
      status:     200,
      headers:    { content_encoding: "gzip" },
      connection: connection,
      request:    HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    result = feature.wrap_response(response)

    assert_equal HTTP::URI.parse("https://example.com"), result.uri
  end

  # -- #stream_for --

  def test_stream_for_returns_an_http_response_body
    result = feature.stream_for(connection)

    assert_instance_of HTTP::Response::Body, result
  end

  def test_stream_for_defaults_to_binary_encoding
    result = feature.stream_for(connection)

    assert_equal Encoding::BINARY, result.encoding
  end

  def test_stream_for_uses_the_given_encoding
    result = feature.stream_for(connection, encoding: Encoding::UTF_8)

    assert_equal Encoding::UTF_8, result.encoding
  end

  def test_stream_for_wraps_the_connection_in_an_inflater
    result = feature.stream_for(connection)
    stream = result.instance_variable_get(:@stream)

    assert_instance_of HTTP::Response::Inflater, stream
  end

  def test_stream_for_passes_the_connection_to_the_inflater
    result = feature.stream_for(connection)
    stream = result.instance_variable_get(:@stream)

    assert_same connection, stream.connection
  end
end
