# frozen_string_literal: true

require "test_helper"
require "logger"

class HTTPFeaturesLoggingTest < Minitest::Test
  cover "HTTP::Features::Logging*"

  def logdev
    @logdev ||= StringIO.new
  end

  def feature
    @feature ||= begin
      logger           = Logger.new(logdev)
      logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
      HTTP::Features::Logging.new(logger: logger)
    end
  end

  # -- NullLogger --

  def test_null_logger_responds_to_log_level_methods
    null_logger = HTTP::Features::Logging::NullLogger.new

    %i[fatal error warn info debug].each do |level|
      assert_nil null_logger.public_send(level, "msg")
    end
  end

  def test_null_logger_reports_all_levels_as_enabled
    null_logger = HTTP::Features::Logging::NullLogger.new

    %i[fatal? error? warn? info? debug?].each do |level|
      assert null_logger.public_send(level)
    end
  end

  # -- default initialization --

  def test_default_initialization_uses_null_logger
    f = HTTP::Features::Logging.new

    assert_instance_of HTTP::Features::Logging::NullLogger, f.logger
  end

  # -- logging the request --

  def test_logging_the_request_logs_the_request
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/",
      headers: { accept: "application/json" },
      body:    '{"hello": "world!"}'
    )
    feature.wrap_request(req)

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

  def test_logging_the_request_returns_the_request
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/",
      headers: { accept: "application/json" },
      body:    '{"hello": "world!"}'
    )
    result = feature.wrap_request(req)

    assert_same req, result
  end

  # -- logging request with string header names --

  def test_logging_request_preserves_original_header_names_without_canonicalization
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/",
      headers: { "X-Custom_Header" => "value1", "X-Another.Header" => "value2" },
      body:    "hello"
    )
    feature.wrap_request(req)

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

  # -- logging request with non-loggable IO body --

  def test_logging_request_with_io_body_logs_headers_without_body
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/upload",
      headers: { content_type: "application/octet-stream" },
      body:    FakeIO.new("binary data")
    )
    feature.wrap_request(req)

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

  # -- logging request with binary-encoded string body --

  def test_logging_request_with_binary_body_logs_binary_stats
    binary_data = String.new("\x89PNG\r\n", encoding: Encoding::BINARY)
    req = HTTP::Request.new(
      verb:    :post,
      uri:     "https://example.com/upload",
      headers: { content_type: "application/octet-stream" },
      body:    binary_data
    )
    feature.wrap_request(req)

    assert_includes logdev.string, "BINARY DATA (6 bytes)"
    refute_includes logdev.string, "\x89PNG"
  end

  # -- logging the response: with a string body --

  def test_logging_response_with_string_body_logs_response_with_body
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/json" },
      body:    '{"success": true}',
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feature.wrap_response(resp)

    expected = <<~OUTPUT
      ** INFO **
      < 200 OK
      ** DEBUG **
      Content-Type: application/json

      {"success": true}
    OUTPUT
    assert_equal expected, logdev.string
  end

  def test_logging_response_with_string_body_returns_same_response_object
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/json" },
      body:    '{"success": true}',
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    result = feature.wrap_response(resp)

    assert_same resp, result
  end

  # -- logging the response: with a streaming body --

  def build_streaming_response
    chunks = %w[{"suc cess" :true}]
    connection_obj = Object.new
    stream = fake(
      readpartial: proc { chunks.shift or raise EOFError },
      close:       nil,
      closed?:     true,
      connection:  connection_obj
    )
    body = HTTP::Response::Body.new(stream, encoding: Encoding::UTF_8)
    request_obj = HTTP::Request.new(verb: :get, uri: "https://example.com")
    response = HTTP::Response.new(
      version:       "1.1",
      status:        200,
      headers:       { content_type: "application/json" },
      proxy_headers: { "X-Via" => "proxy" },
      body:          body,
      request:       request_obj
    )
    [response, body, request_obj, connection_obj]
  end

  def test_logging_streaming_response_does_not_consume_the_body
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_nil wrapped.body.instance_variable_get(:@streaming)
  end

  def test_logging_streaming_response_logs_body_chunks_as_streamed
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)
    wrapped.body.to_s

    assert_includes logdev.string, '{"suc'
    assert_includes logdev.string, 'cess"'
    assert_includes logdev.string, ":true}"
  end

  def test_logging_streaming_response_preserves_full_body_content
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal '{"success":true}', wrapped.body.to_s
  end

  def test_logging_streaming_response_returns_new_response_with_same_status
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal response.status.code, wrapped.status.code
  end

  def test_logging_streaming_response_returns_new_response_with_same_version
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal "1.1", wrapped.version
  end

  def test_logging_streaming_response_returns_new_response_with_same_headers
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal response.headers.to_h, wrapped.headers.to_h
  end

  def test_logging_streaming_response_returns_new_response_with_same_proxy_headers
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal({ "X-Via" => "proxy" }, wrapped.proxy_headers.to_h)
  end

  def test_logging_streaming_response_returns_new_response_preserving_the_request
    response, _, request_obj, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_same request_obj, wrapped.request
  end

  def test_logging_streaming_response_returns_different_response_object
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    refute_same response, wrapped
  end

  def test_logging_streaming_response_preserves_body_encoding
    response, = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_equal Encoding::UTF_8, wrapped.body.encoding
  end

  def test_logging_streaming_response_wraps_underlying_stream_not_body_object
    response, body, = build_streaming_response
    wrapped = feature.wrap_response(response)
    wrapped.body.to_s

    assert_nil body.instance_variable_get(:@streaming)
  end

  def test_logging_streaming_response_logs_headers
    response, = build_streaming_response
    feature.wrap_response(response)

    assert_includes logdev.string, "Content-Type: application/json"
  end

  def test_logging_streaming_response_preserves_connection_on_wrapped_response
    response, _, _, connection_obj = build_streaming_response
    wrapped = feature.wrap_response(response)

    assert_same connection_obj, wrapped.connection
  end

  # -- response with body that does not respond to :encoding --

  def test_logging_response_with_non_encoding_body_logs_without_error
    body_obj = Object.new
    body_obj.define_singleton_method(:to_s) { "inline content" }
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "text/plain" },
      body:    body_obj,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feature.wrap_response(resp)

    assert_includes logdev.string, "inline content"
  end

  def test_logging_response_with_non_encoding_body_returns_same_response_object
    body_obj = Object.new
    body_obj.define_singleton_method(:to_s) { "inline content" }
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "text/plain" },
      body:    body_obj,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    result = feature.wrap_response(resp)

    assert_same resp, result
  end

  # -- response with binary string body --

  def test_logging_response_with_binary_string_body_logs_binary_stats
    binary_data = String.new("\x89PNG\r\n\x1A\n", encoding: Encoding::BINARY)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/octet-stream" },
      body:    binary_data,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feature.wrap_response(resp)

    assert_includes logdev.string, "BINARY DATA (8 bytes)"
    refute_includes logdev.string, "\x89PNG"
  end

  def test_logging_response_with_binary_string_body_includes_headers
    binary_data = String.new("\x89PNG\r\n\x1A\n", encoding: Encoding::BINARY)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/octet-stream" },
      body:    binary_data,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feature.wrap_response(resp)

    assert_includes logdev.string, "Content-Type: application/octet-stream"
  end

  # -- response with binary streaming body --

  def test_logging_response_with_binary_streaming_body_logs_binary_stats
    chunks = [String.new("\x89PNG\r\n", encoding: Encoding::BINARY)]
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

    assert_includes logdev.string, "BINARY DATA (6 bytes)"
    refute_includes logdev.string, "\x89PNG"
  end

  def test_logging_response_with_binary_streaming_body_preserves_full_content
    chunks = [String.new("\x89PNG\r\n", encoding: Encoding::BINARY)]
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

    assert_equal String.new("\x89PNG\r\n", encoding: Encoding::BINARY), wrapped.body.to_s
  end

  # -- response with Response::Body subclass --

  def test_logging_response_with_body_subclass_treats_same_as_response_body
    subclass = Class.new(HTTP::Response::Body)
    chunks = %w[hello world]
    connection_obj = Object.new
    stream = fake(
      readpartial: proc { chunks.shift or raise EOFError },
      close:       nil,
      closed?:     true,
      connection:  connection_obj
    )
    body = subclass.new(stream, encoding: Encoding::UTF_8)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "text/plain" },
      body:    body,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    wrapped = feature.wrap_response(resp)

    refute_same resp, wrapped
    assert_equal "helloworld", wrapped.body.to_s
  end

  # -- when logger level is above debug --

  def test_logging_when_logger_level_above_debug_does_not_wrap_body
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    logger.level = Logger::INFO

    feat = HTTP::Features::Logging.new(logger: logger)
    stream = fake(
      readpartial: proc { raise EOFError },
      close:       nil,
      closed?:     true
    )
    body = HTTP::Response::Body.new(stream)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "text/plain" },
      body:    body,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    wrapped = feat.wrap_response(resp)

    assert_same resp, wrapped
  end

  # -- binary_formatter validation --

  def test_binary_formatter_raises_for_unsupported_values
    err = assert_raises(ArgumentError) do
      HTTP::Features::Logging.new(binary_formatter: :unsupported)
    end
    assert_includes err.message, "binary_formatter must be :stats, :base64, or a callable"
    assert_includes err.message, ":unsupported"
  end

  def test_binary_formatter_accepts_stats
    HTTP::Features::Logging.new(binary_formatter: :stats)
  end

  def test_binary_formatter_accepts_base64
    HTTP::Features::Logging.new(binary_formatter: :base64)
  end

  def test_binary_formatter_accepts_a_callable
    HTTP::Features::Logging.new(binary_formatter: ->(data) { data })
  end

  # -- binary_formatter :base64 --

  def test_binary_formatter_base64_logs_base64_encoded_body
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    feat = HTTP::Features::Logging.new(logger: logger, binary_formatter: :base64)

    binary_data = String.new("\x89PNG\r\n\x1A\n", encoding: Encoding::BINARY)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "image/png" },
      body:    binary_data,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feat.wrap_response(resp)

    assert_includes dev.string, "BINARY DATA (8 bytes)"
    assert_includes dev.string, [binary_data].pack("m0")
  end

  def test_binary_formatter_base64_encodes_streaming_binary_chunks
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    feat = HTTP::Features::Logging.new(logger: logger, binary_formatter: :base64)

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
    wrapped = feat.wrap_response(resp)
    wrapped.body.to_s

    assert_includes dev.string, "BINARY DATA (3 bytes)"
    assert_includes dev.string, ["\xFF\xD8\xFF"].pack("m0")
  end

  # -- binary_formatter Proc --

  def test_binary_formatter_proc_uses_custom_formatter
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    formatter = ->(data) { "[#{data.bytesize} bytes hidden]" }
    feat = HTTP::Features::Logging.new(logger: logger, binary_formatter: formatter)

    binary_data = String.new("\x00\x01\x02", encoding: Encoding::BINARY)
    resp = HTTP::Response.new(
      version: "1.1",
      status:  200,
      headers: { content_type: "application/octet-stream" },
      body:    binary_data,
      request: HTTP::Request.new(verb: :get, uri: "https://example.com")
    )
    feat.wrap_response(resp)

    assert_includes dev.string, "[3 bytes hidden]"
  end

  def test_binary_formatter_proc_uses_custom_formatter_for_streaming_chunks
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }
    formatter = ->(data) { "[#{data.bytesize} bytes hidden]" }
    feat = HTTP::Features::Logging.new(logger: logger, binary_formatter: formatter)

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
    wrapped = feat.wrap_response(resp)
    wrapped.body.to_s

    assert_includes dev.string, "[2 bytes hidden]"
  end

  # -- BodyLogger --

  def test_body_logger_passes_through_chunks_and_logs_them
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    chunks = %w[hello world]
    stream = fake(readpartial: proc { chunks.shift or raise EOFError })
    body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

    assert_equal "hello", body_logger.readpartial
    assert_equal "world", body_logger.readpartial
    assert_raises(EOFError) { body_logger.readpartial }
    assert_includes dev.string, "hello"
    assert_includes dev.string, "world"
  end

  def test_body_logger_forwards_arguments_to_the_underlying_stream
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    received_args = nil
    stream = fake(readpartial: proc { |*args|
      received_args = args
      "data"
    })
    body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)
    body_logger.readpartial(1024)

    assert_equal [1024], received_args
  end

  def test_body_logger_applies_formatter_when_provided
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    chunks = %w[hello world]
    stream = fake(readpartial: proc { chunks.shift or raise EOFError })
    formatter = ->(data) { "FORMATTED: #{data}" }
    body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger, formatter: formatter)

    assert_equal "hello", body_logger.readpartial
    assert_includes dev.string, "FORMATTED: hello"
  end

  def test_body_logger_exposes_the_underlying_connection
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    connection = Object.new
    stream = fake(
      readpartial: proc { raise EOFError },
      connection:  connection
    )
    body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

    assert_same connection, body_logger.connection
  end

  def test_body_logger_uses_stream_as_connection_when_stream_has_no_connection_method
    dev = StringIO.new
    logger = Logger.new(dev)
    logger.formatter = ->(severity, _, _, message) { format("** %s **\n%s\n", severity, message) }

    stream = fake(readpartial: proc { raise EOFError })
    body_logger = HTTP::Features::Logging::BodyLogger.new(stream, logger)

    assert_same stream, body_logger.connection
  end
end
