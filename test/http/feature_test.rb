# frozen_string_literal: true

require "test_helper"

describe HTTP::Feature do
  cover "HTTP::Feature*"
  let(:feature) { HTTP::Feature.new }

  let(:request) { HTTP::Request.new(verb: :get, uri: "http://example.com/") }
  let(:response) do
    HTTP::Response.new(
      version: "1.1",
      status:  200,
      body:    "OK",
      request: request
    )
  end

  describe "#wrap_request" do
    it "returns the same request object" do
      assert_same request, feature.wrap_request(request)
    end
  end

  describe "#wrap_response" do
    it "returns the same response object" do
      assert_same response, feature.wrap_response(response)
    end
  end

  describe "#on_request" do
    it "does not raise" do
      feature.on_request(request)
    end
  end

  describe "#around_request" do
    it "yields the request and returns the response" do
      result = feature.around_request(request) do |req|
        assert_same(request, req)
        response
      end

      assert_same response, result
    end
  end

  describe "#on_error" do
    it "does not raise" do
      feature.on_error(request, RuntimeError.new("boom"))
    end
  end
end
