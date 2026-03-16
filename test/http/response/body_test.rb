# frozen_string_literal: true

require "test_helper"

class HTTPResponseBodyTest < Minitest::Test
  cover "HTTP::Response::Body*"

  def build_connection(chunks)
    fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
  end

  # ---------------------------------------------------------------------------
  # streaming
  # ---------------------------------------------------------------------------
  def test_streams_bodies_from_responses
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    result = body.to_s

    assert_equal "Hello, World!", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  # ---------------------------------------------------------------------------
  # empty body
  # ---------------------------------------------------------------------------
  def test_when_body_empty_responds_to_empty_with_true
    chunks = [""]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert_empty body
  end

  # ---------------------------------------------------------------------------
  # #readpartial
  # ---------------------------------------------------------------------------
  def test_readpartial_with_size_passes_value_to_underlying_connection
    received_size = nil
    conn = Object.new
    conn.define_singleton_method(:readpartial) do |size = nil|
      received_size = size
      "data"
    end
    b = HTTP::Response::Body.new(conn, encoding: Encoding::UTF_8)
    b.readpartial(42)

    assert_equal 42, received_size
  end

  def test_readpartial_without_size_does_not_blow_up
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    body.readpartial
  end

  def test_readpartial_without_size_calls_underlying_without_specific_size
    call_args = nil
    conn = Object.new
    conn.define_singleton_method(:readpartial) do |*args|
      call_args = args
      "data"
    end
    b = HTTP::Response::Body.new(conn, encoding: Encoding::UTF_8)
    b.readpartial

    assert_equal [], call_args
  end

  def test_readpartial_returns_content_in_specified_encoding
    conn1 = fake(readpartial: proc { String.new("content", encoding: Encoding::UTF_8) })
    b1 = HTTP::Response::Body.new(conn1)

    assert_equal Encoding::BINARY, b1.readpartial.encoding

    conn2 = fake(readpartial: proc { String.new("content", encoding: Encoding::BINARY) })
    b2 = HTTP::Response::Body.new(conn2, encoding: Encoding::UTF_8)

    assert_equal Encoding::UTF_8, b2.readpartial.encoding
  end

  # ---------------------------------------------------------------------------
  # #each
  # ---------------------------------------------------------------------------
  def test_each_yields_each_chunk
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    collected = body.map { |chunk| chunk }

    assert_equal "Hello, World!", collected.join
  end

  # ---------------------------------------------------------------------------
  # #to_s when streaming
  # ---------------------------------------------------------------------------
  def test_to_s_raises_state_error_if_body_is_being_streamed
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    body.readpartial
    err = assert_raises(HTTP::StateError) { body.to_s }
    assert_match(/body is being streamed/, err.message)
  end

  # ---------------------------------------------------------------------------
  # #stream! after consumption
  # ---------------------------------------------------------------------------
  def test_readpartial_raises_state_error_if_body_already_consumed
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    body.to_s
    err = assert_raises(HTTP::StateError) { body.readpartial }
    assert_match(/body has already been consumed/, err.message)
  end

  # ---------------------------------------------------------------------------
  # #to_s
  # ---------------------------------------------------------------------------
  def test_to_s_returns_same_string_on_subsequent_calls
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    first  = body.to_s
    second = body.to_s

    assert_equal "Hello, World!", first
    assert_same first, second
  end

  def test_to_s_re_raises_error_when_error_occurs_during_reading
    connection = fake(readpartial: proc { raise IOError, "read error" })
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert_raises(IOError) { body.to_s }
  end

  def test_to_s_raises_state_error_on_subsequent_call_after_error
    connection = fake(readpartial: proc { raise IOError, "read error" })
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert_raises(IOError) { body.to_s }

    err = assert_raises(HTTP::StateError) { body.to_s }
    assert_match(/body is being streamed/, err.message)
  end

  # ---------------------------------------------------------------------------
  # #loggable?
  # ---------------------------------------------------------------------------
  def test_loggable_with_text_encoding_returns_true
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert_predicate body, :loggable?
  end

  def test_loggable_with_binary_encoding_returns_false
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection)

    refute_predicate body, :loggable?
  end

  # ---------------------------------------------------------------------------
  # #connection
  # ---------------------------------------------------------------------------
  def test_connection_returns_streams_connection_when_stream_responds_to_connection
    inner_conn = Object.new
    stream = fake(
      connection:  inner_conn,
      readpartial: proc { raise EOFError }
    )
    b = HTTP::Response::Body.new(stream)

    assert_same inner_conn, b.connection
  end

  def test_connection_returns_stream_itself_when_stream_does_not_respond_to_connection
    stream = fake(readpartial: proc { raise EOFError })
    b = HTTP::Response::Body.new(stream)

    assert_same stream, b.connection
  end

  # ---------------------------------------------------------------------------
  # #initialize
  # ---------------------------------------------------------------------------
  def test_initialize_explicitly_initializes_streaming
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert body.instance_variable_defined?(:@streaming)
  end

  def test_initialize_explicitly_initializes_contents
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)

    assert body.instance_variable_defined?(:@contents)
  end

  # ---------------------------------------------------------------------------
  # #inspect
  # ---------------------------------------------------------------------------
  def test_inspect_includes_class_name_hex_object_id_and_streaming_state
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8)
    result = body.inspect
    hex_id = body.object_id.to_s(16)

    assert_equal "#<HTTP::Response::Body:#{hex_id} @streaming=false>", result
  end

  # ---------------------------------------------------------------------------
  # invalid encoding
  # ---------------------------------------------------------------------------
  def test_with_invalid_encoding_falls_back_to_binary
    chunks = ["Hello, ", "World!"]
    connection = build_connection(chunks)
    body = HTTP::Response::Body.new(connection, encoding: "nonexistent-encoding")

    assert_equal Encoding::BINARY, body.to_s.encoding
  end

  # ---------------------------------------------------------------------------
  # gzipped body
  # ---------------------------------------------------------------------------
  def test_gzipped_body_decodes_body
    compressed = Zlib::Deflate.deflate("Hi, HTTP here \u263A")
    len = compressed.length
    chunks = [compressed[0, len / 2], compressed[(len / 2)..]]
    connection = build_connection(chunks)
    inflater = HTTP::Response::Inflater.new(connection)
    body = HTTP::Response::Body.new(inflater, encoding: Encoding::UTF_8)

    assert_equal "Hi, HTTP here \u263A", body.to_s
  end

  def test_gzipped_body_readpartial_streams_decoded_body
    compressed = Zlib::Deflate.deflate("Hi, HTTP here \u263A")
    len = compressed.length
    chunks = [compressed[0, len / 2], compressed[(len / 2)..]]
    connection = build_connection(chunks)
    inflater = HTTP::Response::Inflater.new(connection)
    body = HTTP::Response::Body.new(inflater, encoding: Encoding::UTF_8)

    assert_equal "Hi, HTTP ", body.readpartial
    assert_equal "here \u263A", body.readpartial
    assert_raises(EOFError) { body.readpartial }
  end

  # ---------------------------------------------------------------------------
  # inflater with non-gzip data
  # ---------------------------------------------------------------------------
  def test_inflater_with_non_gzip_data_does_not_raise_zlib_buf_error
    chunks = [" "]
    connection = build_connection(chunks)
    inflater = HTTP::Response::Inflater.new(connection)
    body = HTTP::Response::Body.new(inflater, encoding: Encoding::UTF_8)

    assert_equal "", body.to_s
  end

  # ---------------------------------------------------------------------------
  # inflater with EOFError without prior data
  # ---------------------------------------------------------------------------
  def test_inflater_closes_zstream_and_re_raises_on_eof_without_prior_data
    conn = fake(readpartial: proc { raise EOFError })
    inflater = HTTP::Response::Inflater.new(conn)

    assert_raises(EOFError) { inflater.readpartial }
  end

  def test_inflater_handles_repeated_eof_after_zstream_already_closed
    conn = fake(readpartial: proc { raise EOFError })
    inflater = HTTP::Response::Inflater.new(conn)

    assert_raises(EOFError) { inflater.readpartial }
    assert_raises(EOFError) { inflater.readpartial }
  end
end
