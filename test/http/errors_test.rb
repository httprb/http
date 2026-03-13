# frozen_string_literal: true

require "test_helper"

describe HTTP::StatusError do
  cover "HTTP::StatusError*"

  let(:response) do
    HTTP::Response.new(
      status:  404,
      version: "1.1",
      body:    "Not Found",
      request: HTTP::Request.new(verb: :get, uri: "http://example.com/")
    )
  end

  let(:error) { HTTP::StatusError.new(response) }

  describe "#response" do
    it "returns the response" do
      assert_same response, error.response
    end
  end

  describe "#message" do
    it "includes the status code" do
      assert_equal "Unexpected status code 404", error.message
    end
  end
end
