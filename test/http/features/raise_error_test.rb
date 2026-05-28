# frozen_string_literal: true

require "test_helper"

class HTTPFeaturesRaiseErrorTest < Minitest::Test
  cover "HTTP::Features::RaiseError*"

  def connection
    @connection ||= fake
  end

  def build_response(status:)
    HTTP::Response.new(
      version:    "1.1",
      status:     status,
      headers:    {},
      connection: connection,
      request:    HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
  end

  # -- #wrap_response --

  def test_wrap_response_when_status_is_200_returns_original_response
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 200)
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_when_status_is_399_returns_original_response
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 399)
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_when_status_is_400_raises_bad_request_error
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 400)
    err = assert_raises(HTTP::BadRequestError) { feature.wrap_response(response) }
    assert_equal "Unexpected status code 400", err.message
  end

  def test_wrap_response_when_status_is_500_raises_internal_server_error
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 500)
    err = assert_raises(HTTP::InternalServerError) { feature.wrap_response(response) }
    assert_equal "Unexpected status code 500", err.message
  end

  def test_wrap_response_when_unmapped_4xx_status_raises_client_error
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 499)
    err = assert_raises(HTTP::ClientError) { feature.wrap_response(response) }
    assert_equal "Unexpected status code 499", err.message
  end

  def test_wrap_response_when_unmapped_5xx_status_raises_server_error
    feature = HTTP::Features::RaiseError.new(ignore: [])
    response = build_response(status: 599)
    err = assert_raises(HTTP::ServerError) { feature.wrap_response(response) }
    assert_equal "Unexpected status code 599", err.message
  end

  def test_each_error_code
    HTTP::Features::RaiseError::CODE_TO_ERROR_CLASS.each do |status, expected_error_class|
      feature = HTTP::Features::RaiseError.new(ignore: [])
      response = build_response(status: status)
      err = assert_raises(expected_error_class) { feature.wrap_response(response) }
      refute_nil err.message
    end
  end

  # -- #initialize --

  def test_initialize_defaults_ignore_to_empty_array
    feature = HTTP::Features::RaiseError.new
    response = HTTP::Response.new(
      version: "1.1", status: 500, headers: {},
      connection: connection,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    assert_raises(HTTP::StatusError) { feature.wrap_response(response) }
  end

  def test_initialize_is_a_feature
    assert_kind_of HTTP::Feature, HTTP::Features::RaiseError.new
  end

  def test_wrap_response_when_status_is_400_and_ignored_returns_original_response
    feature = HTTP::Features::RaiseError.new(ignore: [400])
    response = build_response(status: 400)
    result = feature.wrap_response(response)

    assert_same response, result
  end

  def test_wrap_response_when_status_is_500_and_ignored_returns_original_response
    feature = HTTP::Features::RaiseError.new(ignore: [500])
    response = build_response(status: 500)
    result = feature.wrap_response(response)

    assert_same response, result
  end
end
