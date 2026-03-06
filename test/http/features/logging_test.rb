# frozen_string_literal: true

require "test_helper"
require "logger"

describe HTTP::Features::Logging do
  let(:logdev) { StringIO.new }

  let(:feature) do
    logger           = Logger.new(logdev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    HTTP::Features::Logging.new(logger: logger)
  end

  describe "NullLogger" do
    let(:null_logger) { HTTP::Features::Logging::NullLogger.new }

    it "responds to log level methods" do
      %i[fatal error warn info debug].each do |level|
        assert_nil null_logger.public_send(level, "msg")
      end
    end

    it "reports all levels as enabled" do
      %i[fatal? error? warn? info? debug?].each do |level|
        assert null_logger.public_send(level)
      end
    end
  end

  describe "logging the request" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { accept: "application/json" },
        body:    '{"hello": "world!"}'
      )
    end

    it "logs the request" do
      feature.wrap_request(request)

      expected = <<~OUTPUT
        ** INFO **
        > POST https://example.com/
        ** DEBUG **
        Accept: application/json
        Host: example.com
        User-Agent: http.rb/#{HTTP::VERSION}

        {"hello": "world!"}
      OUTPUT
      assert_equal expected, logdev.string
    end
  end

  describe "logging the response" do
    let(:response) do
      HTTP::Response.new(
        version: "1.1",
        status:  200,
        headers: { content_type: "application/json" },
        body:    '{"success": true}',
        request: HTTP::Request.new(verb: :get, uri: "https://example.com")
      )
    end

    it "logs the response" do
      feature.wrap_response(response)

      expected = <<~OUTPUT
        ** INFO **
        < 200 OK
        ** DEBUG **
        Content-Type: application/json

        {"success": true}
      OUTPUT
      assert_equal expected, logdev.string
    end
  end
end
