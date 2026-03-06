# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::RaiseError do
  let(:feature)    { HTTP::Features::RaiseError.new(ignore: ignore) }
  let(:connection) { fake }
  let(:status)     { 200 }
  let(:ignore)     { [] }

  describe "#wrap_response" do
    let(:response) do
      HTTP::Response.new(
        version:    "1.1",
        status:     status,
        headers:    {},
        connection: connection,
        request:    HTTP::Request.new(verb: :get, uri: "https://example.com")
      )
    end

    let(:result) { feature.wrap_response(response) }

    context "when status is 200" do
      it "returns original request" do
        assert_same response, result
      end
    end

    context "when status is 399" do
      let(:status) { 399 }

      it "returns original request" do
        assert_same response, result
      end
    end

    context "when status is 400" do
      let(:status) { 400 }

      it "raises" do
        err = assert_raises(HTTP::StatusError) { result }
        assert_equal "Unexpected status code 400", err.message
      end
    end

    context "when status is 599" do
      let(:status) { 599 }

      it "raises" do
        err = assert_raises(HTTP::StatusError) { result }
        assert_equal "Unexpected status code 599", err.message
      end
    end

    context "when error status is ignored" do
      let(:status) { 500 }
      let(:ignore) { [500] }

      it "returns original request" do
        assert_same response, result
      end
    end
  end
end
