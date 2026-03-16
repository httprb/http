# frozen_string_literal: true

require "test_helper"

class HTTPStatusErrorTest < Minitest::Test
  cover "HTTP::StatusError*"

  def response
    @response ||= HTTP::Response.new(
      status:  404,
      version: "1.1",
      body:    "Not Found",
      request: HTTP::Request.new(verb: :get, uri: "http://example.com/")
    )
  end

  def error
    @error ||= HTTP::StatusError.new(response)
  end

  def test_response_returns_the_response
    assert_same response, error.response
  end

  def test_message_includes_the_status_code
    assert_equal "Unexpected status code 404", error.message
  end
end
