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

  describe "default initialization" do
    it "uses NullLogger when no logger is provided" do
      feature = HTTP::Features::Logging.new

      assert_instance_of HTTP::Features::Logging::NullLogger, feature.logger
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

    it "returns the request" do
      result = feature.wrap_request(request)

      assert_same request, result
    end
  end

  describe "logging the request with string header names" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/",
        headers: { "X-Custom_Header" => "value1", "X-Another.Header" => "value2" },
        body:    "hello"
      )
    end

    it "preserves original header names without canonicalization" do
      feature.wrap_request(request)

      expected = <<~OUTPUT
        ** INFO **
        > POST https://example.com/
        ** DEBUG **
        X-Custom_Header: value1
        X-Another.Header: value2
        Host: example.com
        User-Agent: http.rb/#{HTTP::VERSION}

        hello
      OUTPUT
      assert_equal expected, logdev.string
    end
  end

  describe "logging the request with non-loggable IO body" do
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/upload",
        headers: { content_type: "application/octet-stream" },
        body:    FakeIO.new("binary data")
      )
    end

    it "logs headers without the body" do
      feature.wrap_request(request)

      expected = <<~OUTPUT
        ** INFO **
        > POST https://example.com/upload
        ** DEBUG **
        Content-Type: application/octet-stream
        Host: example.com
        User-Agent: http.rb/#{HTTP::VERSION}
      OUTPUT
      assert_equal expected, logdev.string
    end
  end

  describe "logging the request with binary-encoded string body" do
    let(:binary_data) { String.new("\x89PNG\r\n", encoding: Encoding::BINARY) }
    let(:request) do
      HTTP::Request.new(
        verb:    :post,
        uri:     "https://example.com/upload",
        headers: { content_type: "application/octet-stream" },
        body:    binary_data
      )
    end

    it "logs binary stats instead of raw content" do
      feature.wrap_request(request)

      assert_includes logdev.string, "BINARY DATA (6 bytes)"
      refute_includes logdev.string, "\x89PNG"
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

      it "returns the same response object for inline bodies" do
        result = feature.wrap_response(response)

        assert_same response, result
      end
    end

    context "with a streaming body" do
      let(:chunks) { %w[{"suc cess" :true}] }
      let(:connection_obj) { Object.new }
      let(:stream) do
        fake(
          readpartial: proc { chunks.shift or raise EOFError },
          close:       nil,
          closed?:     true,
          connection:  connection_obj
        )
      end
      let(:body) { HTTP::Response::Body.new(stream, encoding: Encoding::UTF_8) }
      let(:request_obj) { HTTP::Request.new(verb: :get, uri: "https://example.com") }
      let(:response) do
        HTTP::Response.new(
          version:       "1.1",
          status:        200,
          headers:       { content_type: "application/json" },
          proxy_headers: { "X-Via" => "proxy" },
          body:          body,
          request:       request_obj
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

      it "returns a new response with the same status" do
        wrapped = feature.wrap_response(response)

        assert_equal response.status.code, wrapped.status.code
      end

      it "returns a new response with the same version" do
        wrapped = feature.wrap_response(response)

        assert_equal "1.1", wrapped.version
      end

      it "returns a new response with the same headers" do
        wrapped = feature.wrap_response(response)

        assert_equal response.headers.to_h, wrapped.headers.to_h
      end

      it "returns a new response with the same proxy_headers" do
        wrapped = feature.wrap_response(response)

        assert_equal({ "X-Via" => "proxy" }, wrapped.proxy_headers.to_h)
      end

      it "returns a new response preserving the request" do
        wrapped = feature.wrap_response(response)

        assert_same request_obj, wrapped.request
      end

      it "returns a different response object wrapping the body" do
        wrapped = feature.wrap_response(response)

        refute_same response, wrapped
      end

      it "preserves the body encoding" do
        wrapped = feature.wrap_response(response)

        assert_equal Encoding::UTF_8, wrapped.body.encoding
      end

      it "wraps the underlying stream, not the body object" do
        wrapped = feature.wrap_response(response)
        wrapped.body.to_s

        # The original body should not be marked as streaming, because the
        # BodyLogger should wrap the underlying stream directly
        assert_nil body.instance_variable_get(:@streaming)
      end

      it "logs headers for streaming responses" do
        feature.wrap_response(response)

        assert_includes logdev.string, "Content-Type: application/json"
      end

      it "preserves the connection on the wrapped response" do
        wrapped = feature.wrap_response(response)

        assert_same connection_obj, wrapped.connection
      end
    end

    context "with a body that does not respond to :encoding" do
      let(:body_obj) do
        obj = Object.new
        obj.define_singleton_method(:to_s) { "inline content" }
        obj
      end
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "text/plain" },
          body:    body_obj,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "logs the body without error" do
        feature.wrap_response(response)

        assert_includes logdev.string, "inline content"
      end

      it "returns the same response object" do
        result = feature.wrap_response(response)

        assert_same response, result
      end
    end

    context "with a binary string body" do
      let(:binary_data) { String.new("\x89PNG\r\n\x1A\n", encoding: Encoding::BINARY) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "application/octet-stream" },
          body:    binary_data,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "logs binary stats instead of raw content" do
        feature.wrap_response(response)

        assert_includes logdev.string, "BINARY DATA (8 bytes)"
        refute_includes logdev.string, "\x89PNG"
      end

      it "includes the headers in the log output" do
        feature.wrap_response(response)

        assert_includes logdev.string, "Content-Type: application/octet-stream"
      end
    end

    context "with a binary streaming body" do
      let(:chunks) { [String.new("\x89PNG\r\n", encoding: Encoding::BINARY)] }
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
          headers: { content_type: "application/octet-stream" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "logs binary stats for each chunk instead of raw content" do
        wrapped = feature.wrap_response(response)
        wrapped.body.to_s

        assert_includes logdev.string, "BINARY DATA (6 bytes)"
        refute_includes logdev.string, "\x89PNG"
      end

      it "preserves the full body content" do
        wrapped = feature.wrap_response(response)

        assert_equal String.new("\x89PNG\r\n", encoding: Encoding::BINARY), wrapped.body.to_s
      end
    end

    context "with a Response::Body subclass" do
      let(:subclass) { Class.new(HTTP::Response::Body) }
      let(:chunks) { %w[hello world] }
      let(:connection_obj) { Object.new }
      let(:stream) do
        fake(
          readpartial: proc { chunks.shift or raise EOFError },
          close:       nil,
          closed?:     true,
          connection:  connection_obj
        )
      end
      let(:body) { subclass.new(stream, encoding: Encoding::UTF_8) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "text/plain" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "treats subclasses the same as Response::Body" do
        wrapped = feature.wrap_response(response)

        refute_same response, wrapped
        assert_equal "helloworld", wrapped.body.to_s
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

  describe "binary_formatter validation" do
    it "raises ArgumentError for unsupported values" do
      err = assert_raises(ArgumentError) do
        HTTP::Features::Logging.new(binary_formatter: :unsupported)
      end
      assert_includes err.message, "binary_formatter must be :stats, :base64, or a callable"
      assert_includes err.message, ":unsupported"
    end

    it "accepts :stats" do
      HTTP::Features::Logging.new(binary_formatter: :stats)
    end

    it "accepts :base64" do
      HTTP::Features::Logging.new(binary_formatter: :base64)
    end

    it "accepts a callable" do
      HTTP::Features::Logging.new(binary_formatter: ->(data) { data })
    end
  end

  describe "binary_formatter option" do
    context "with :base64 formatter" do
      let(:feature) do
        logger           = Logger.new(logdev)
        logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

        HTTP::Features::Logging.new(logger: logger, binary_formatter: :base64)
      end

      let(:binary_data) { String.new("\x89PNG\r\n\x1A\n", encoding: Encoding::BINARY) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "image/png" },
          body:    binary_data,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "logs base64-encoded body" do
        feature.wrap_response(response)

        assert_includes logdev.string, "BINARY DATA (8 bytes)"
        assert_includes logdev.string, [binary_data].pack("m0")
      end

      it "base64-encodes streaming binary chunks" do
        chunks = [String.new("\xFF\xD8\xFF", encoding: Encoding::BINARY)]
        stream = fake(
          readpartial: proc { chunks.shift or raise EOFError },
          close:       nil,
          closed?:     true
        )
        body = HTTP::Response::Body.new(stream)
        resp = HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "image/jpeg" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )

        wrapped = feature.wrap_response(resp)
        wrapped.body.to_s

        assert_includes logdev.string, "BINARY DATA (3 bytes)"
        assert_includes logdev.string, ["\xFF\xD8\xFF"].pack("m0")
      end
    end

    context "with Proc formatter" do
      let(:feature) do
        logger           = Logger.new(logdev)
        logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

        formatter = ->(data) { "[#{data.bytesize} bytes hidden]" }
        HTTP::Features::Logging.new(logger: logger, binary_formatter: formatter)
      end

      let(:binary_data) { String.new("\x00\x01\x02", encoding: Encoding::BINARY) }
      let(:response) do
        HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "application/octet-stream" },
          body:    binary_data,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )
      end

      it "uses the custom formatter" do
        feature.wrap_response(response)

        assert_includes logdev.string, "[3 bytes hidden]"
      end

      it "uses the custom formatter for streaming chunks" do
        chunks = [String.new("\xDE\xAD", encoding: Encoding::BINARY)]
        stream = fake(
          readpartial: proc { chunks.shift or raise EOFError },
          close:       nil,
          closed?:     true
        )
        body = HTTP::Response::Body.new(stream)
        resp = HTTP::Response.new(
          version: "1.1",
          status:  200,
          headers: { content_type: "application/octet-stream" },
          body:    body,
          request: HTTP::Request.new(verb: :get, uri: "https://example.com")
        )

        wrapped = feature.wrap_response(resp)
        wrapped.body.to_s

        assert_includes logdev.string, "[2 bytes hidden]"
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

    it "forwards arguments to the underlying stream" do
      received_args = nil
      stream = fake(readpartial: proc { |*args|
        received_args = args
        "data"
      })

      body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)
      body_logger.readpartial(1024)

      assert_equal [1024], received_args
    end

    it "applies formatter when provided" do
      chunks = %w[hello world]
      stream = fake(readpartial: proc { chunks.shift or raise EOFError })
      formatter = ->(data) { "FORMATTED: #{data}" }

      body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger, formatter: formatter)

      assert_equal "hello", body_logger.readpartial
      assert_includes logdev.string, "FORMATTED: hello"
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
