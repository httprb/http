# frozen_string_literal: true

require "test_helper"

class HTTPFeatureTest < Minitest::Test
  cover "HTTP::Feature*"

  def feature
    @feature ||= HTTP::Feature.new
  end

  def request
    @request ||= HTTP::Request.new(verb: :get, uri: "http://example.com/")
  end

  def response
    @response ||= HTTP::Response.new(
      version: "1.1",
      status:  200,
      body:    "OK",
      request: request
    )
  end

  def test_wrap_request_returns_the_same_request_object
    assert_same request, feature.wrap_request(request)
  end

  def test_wrap_response_returns_the_same_response_object
    assert_same response, feature.wrap_response(response)
  end

  def test_on_request_does_not_raise
    feature.on_request(request)
  end

  def test_around_request_yields_the_request_and_returns_the_response
    result = feature.around_request(request) do |req|
      assert_same(request, req)
      response
    end

    assert_same response, result
  end

  def test_on_error_does_not_raise
    feature.on_error(request, RuntimeError.new("boom"))
  end
end
