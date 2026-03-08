# frozen_string_literal: true

require "test_helper"
require "logger"

describe HTTP::Features::Logging do
  cover "HTTP::Features::Logging*"
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
    context "with a string body" do
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "application/json" },
          body:    '{"success": true}',
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "logs the response with body" do
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

    context "with a streaming body" do
      let(:chunks) { %w[{"suc cess" :true}] }
      let(:stream) do
        fake(
          readpartial: proc { chunks.shift or raise EOFError },
          close:       nil,
          closed?:     true
        )
      end
      let(:body) { HTTP::Response::Body.new(stream) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "application/json" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "does not consume the body" do
        wrapped = feature.wrap_response(response)

        assert_nil wrapped.body.instance_variable_get(:@streaming)
      end

      it "logs body chunks as they are streamed" do
        wrapped = feature.wrap_response(response)
        wrapped.body.to_s

        assert_includes logdev.string, '{"suc'
        assert_includes logdev.string, 'cess"'
        assert_includes logdev.string, ":true}"
      end

      it "preserves the full body content" do
        wrapped = feature.wrap_response(response)

        assert_equal '{"success":true}', wrapped.body.to_s
      end
    end

    context "when logger level is above debug" do
      let(:feature) do
        logger           = Logger.new(logdev)
        logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
        logger.level     = Logger::INFO

        HTTP::Features::Logging.new(logger: logger)
      end

      let(:stream) do
        fake(
          readpartial: proc { raise EOFError },
          close:       nil,
          closed?:     true
        )
      end
      let(:body) { HTTP::Response::Body.new(stream) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "text/plain" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "does not wrap the body" do
        wrapped = feature.wrap_response(response)

        assert_same response, wrapped
      end
    end
  end

  describe "BodyLogger" do
    let(:logger) do
      logger           = Logger.new(logdev)
      logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
      logger
    end

    it "passes through chunks and logs them" do
      chunks = %w[hello world]
      stream = fake(readpartial: proc { chunks.shift or raise EOFError })

      body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

      assert_equal "hello", body_logger.readpartial
      assert_equal "world", body_logger.readpartial
      assert_raises(EOFError) { body_logger.readpartial }
      assert_includes logdev.string, "hello"
      assert_includes logdev.string, "world"
    end

    it "exposes the underlying connection" do
      connection = Object.new
      stream = fake(
        readpartial: proc { raise EOFError },
        connection:  connection
      )

      body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

      assert_same connection, body_logger.connection
    end

    it "uses the stream as connection when stream has no connection method" do
      stream = fake(readpartial: proc { raise EOFError })

      body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

      assert_same stream, body_logger.connection
    end
  end
end
