# frozen_string_literal: true

require "test_helper"

class HTTPRequestWriterTest < Minitest::Test
  cover "HTTP::Request::Writer*"

  def build_writer(io: StringIO.new, body: HTTP::Request::Body.new(""), headers: HTTP::Headers.new,
                   headerstart: "GET /test HTTP/1.1")
    HTTP::Request::Writer.new(io, body, headers, headerstart)
  end

  # #stream

  def test_stream_with_multiple_headers_separates_with_crlf
    io = StringIO.new
    headers = HTTP::Headers.coerce "Host" => "example.org"
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, headers: headers, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "Host: example.org\r\nContent-Length: 0\r\n\r\n"
    ].join, io.string
  end

  def test_stream_with_mixed_case_headers_writes_with_same_casing
    io = StringIO.new
    headers = HTTP::Headers.coerce "content-Type" => "text", "X_MAX" => "200"
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, headers: headers, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "content-Type: text\r\nX_MAX: 200\r\nContent-Length: 0\r\n\r\n"
    ].join, io.string
  end

  def test_stream_with_nonempty_body_writes_body_and_sets_content_length
    io = StringIO.new
    body = HTTP::Request::Body.new("content")
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "Content-Length: 7\r\n\r\n",
      "content"
    ].join, io.string
  end

  def test_stream_when_body_is_not_set_does_not_write_body_or_content_length
    io = StringIO.new
    body = HTTP::Request::Body.new(nil)
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headerstart: headerstart)
    writer.stream

    assert_equal "#{headerstart}\r\n\r\n", io.string
  end

  def test_stream_when_body_is_empty_sets_content_length_zero
    io = StringIO.new
    body = HTTP::Request::Body.new("")
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "Content-Length: 0\r\n\r\n"
    ].join, io.string
  end

  def test_stream_when_content_length_header_is_set_keeps_given_value
    io = StringIO.new
    headers = HTTP::Headers.coerce "Content-Length" => "12"
    body = HTTP::Request::Body.new("content")
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headers: headers, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "Content-Length: 12\r\n\r\n",
      "content"
    ].join, io.string
  end

  def test_stream_when_transfer_encoding_is_chunked_writes_encoded_content
    io = StringIO.new
    headers = HTTP::Headers.coerce "Transfer-Encoding" => "chunked"
    body = HTTP::Request::Body.new(%w[request body])
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headers: headers, headerstart: headerstart)
    writer.stream

    assert_equal [
      "#{headerstart}\r\n",
      "Transfer-Encoding: chunked\r\n\r\n",
      "7\r\nrequest\r\n4\r\nbody\r\n0\r\n\r\n"
    ].join, io.string
  end

  def test_stream_when_transfer_encoding_chunked_with_large_body_encodes_hex
    io = StringIO.new
    headers = HTTP::Headers.coerce "Transfer-Encoding" => "chunked"
    body = HTTP::Request::Body.new(["a" * 255])
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headers: headers, headerstart: headerstart)
    writer.stream

    assert_includes io.string, "ff\r\n#{'a' * 255}\r\n"
  end

  def test_stream_when_transfer_encoding_is_not_chunked_does_not_treat_as_chunked
    io = StringIO.new
    headers = HTTP::Headers.coerce "Transfer-Encoding" => "gzip"
    body = HTTP::Request::Body.new("content")
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(io: io, body: body, headers: headers, headerstart: headerstart)
    writer.stream

    refute_includes io.string, "0\r\n\r\n"
    assert_includes io.string, "content"
  end

  def test_stream_when_transfer_encoding_is_not_chunked_returns_false_from_chunked
    headers = HTTP::Headers.coerce "Transfer-Encoding" => "gzip"
    body = HTTP::Request::Body.new("content")
    writer = build_writer(body: body, headers: headers)

    refute_predicate writer, :chunked?
  end

  def test_stream_when_server_wont_accept_data_aborts_silently
    mock_io = Object.new
    mock_io.define_singleton_method(:write) { |*| raise Errno::EPIPE }
    body = HTTP::Request::Body.new("")
    headers = HTTP::Headers.new
    w = HTTP::Request::Writer.new(mock_io, body, headers, "GET /test HTTP/1.1")
    w.stream
  end

  def test_stream_when_body_is_nil_on_post_request_sets_content_length_to_zero
    io = StringIO.new
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headerstart: "POST /test HTTP/1.1")
    writer.stream

    assert_equal "POST /test HTTP/1.1\r\nContent-Length: 0\r\n\r\n", io.string
  end

  def test_stream_when_body_is_nil_on_head_request_omits_content_length
    io = StringIO.new
    headers = HTTP::Headers.coerce "Host" => "example.org"
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headers: headers, headerstart: "HEAD /test HTTP/1.1")
    writer.stream

    refute_includes io.string, "Content-Length"
  end

  def test_stream_when_body_is_nil_on_delete_request_omits_content_length
    io = StringIO.new
    headers = HTTP::Headers.coerce "Host" => "example.org"
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headers: headers, headerstart: "DELETE /test HTTP/1.1")
    writer.stream

    refute_includes io.string, "Content-Length"
  end

  def test_stream_when_body_is_nil_on_connect_request_omits_content_length
    io = StringIO.new
    headers = HTTP::Headers.coerce "Host" => "example.com:443"
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headers: headers, headerstart: "CONNECT example.com:443 HTTP/1.1")
    writer.stream

    refute_includes io.string, "Content-Length"
  end

  def test_stream_when_socket_raises_exception_raises_connection_error
    mock_io = Object.new
    mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
    body = HTTP::Request::Body.new("")
    headers = HTTP::Headers.new
    w = HTTP::Request::Writer.new(mock_io, body, headers, "GET /test HTTP/1.1")

    assert_raises(HTTP::ConnectionError) { w.stream }
  end

  def test_stream_when_socket_raises_exception_includes_original_error_message
    mock_io = Object.new
    mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
    body = HTTP::Request::Body.new("")
    headers = HTTP::Headers.new
    w = HTTP::Request::Writer.new(mock_io, body, headers, "GET /test HTTP/1.1")
    err = assert_raises(HTTP::ConnectionError) { w.stream }

    assert_includes err.message, "error writing to socket:"
    assert_includes err.message, "Connection reset by peer"
  end

  def test_stream_when_socket_raises_exception_preserves_original_backtrace
    mock_io = Object.new
    mock_io.define_singleton_method(:write) { |*| raise Errno::ECONNRESET }
    body = HTTP::Request::Body.new("")
    headers = HTTP::Headers.new
    w = HTTP::Request::Writer.new(mock_io, body, headers, "GET /test HTTP/1.1")
    err = assert_raises(HTTP::ConnectionError) { w.stream }

    assert_includes err.backtrace.first, "writer_test.rb"
  end

  def test_stream_when_socket_performs_partial_writes_writes_remaining_data
    written = []
    call_count = 0
    mock_io = Object.new
    mock_io.define_singleton_method(:write) do |data|
      call_count += 1
      bytes = call_count == 1 ? [5, data.bytesize].min : data.bytesize
      written << data.byteslice(0, bytes)
      bytes
    end

    body = HTTP::Request::Body.new("HelloWorld")
    w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, "GET /test HTTP/1.1")
    w.stream

    full_output = written.join

    assert_includes full_output, "HelloWorld"
  end

  # #connect_through_proxy

  def test_connect_through_proxy_writes_headers_without_body
    io = StringIO.new
    writer = build_writer(io: io)
    writer.connect_through_proxy

    assert_equal "GET /test HTTP/1.1\r\n\r\n", io.string
  end

  def test_connect_through_proxy_with_headers_includes_headers
    io = StringIO.new
    headers = HTTP::Headers.coerce "Host" => "example.org"
    writer = build_writer(io: io, headers: headers)
    writer.connect_through_proxy

    assert_equal "GET /test HTTP/1.1\r\nHost: example.org\r\n\r\n", io.string
  end

  def test_connect_through_proxy_when_socket_raises_epipe_propagates_error
    mock_io = Object.new
    mock_io.define_singleton_method(:write) { |*| raise Errno::EPIPE }
    body = HTTP::Request::Body.new("")
    headers = HTTP::Headers.new
    w = HTTP::Request::Writer.new(mock_io, body, headers, "GET /test HTTP/1.1")

    assert_raises(Errno::EPIPE) { w.connect_through_proxy }
  end

  # #each_chunk

  def test_each_chunk_when_body_has_content_yields_headers_combined_with_first_chunk
    body = HTTP::Request::Body.new("content")
    writer = build_writer(body: body)
    writer.add_headers
    writer.add_body_type_headers
    chunks = []
    writer.each_chunk { |chunk| chunks << chunk.dup }

    assert_equal 1, chunks.length
    assert_includes chunks.first, "content"
  end

  def test_each_chunk_when_body_is_empty_yields_headers_only_once
    body = HTTP::Request::Body.new("")
    headerstart = "GET /test HTTP/1.1"
    writer = build_writer(body: body, headerstart: headerstart)
    writer.add_headers
    writer.add_body_type_headers
    chunks = []
    writer.each_chunk { |chunk| chunks << chunk.dup }

    assert_equal 1, chunks.length
    assert_includes chunks.first, headerstart
  end

  # #add_body_type_headers

  def test_add_body_type_headers_when_body_is_nil_on_put_sets_content_length_zero
    io = StringIO.new
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headerstart: "PUT /test HTTP/1.1")
    writer.stream

    assert_includes io.string, "Content-Length: 0"
  end

  def test_add_body_type_headers_when_body_is_nil_on_patch_sets_content_length_zero
    io = StringIO.new
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headerstart: "PATCH /test HTTP/1.1")
    writer.stream

    assert_includes io.string, "Content-Length: 0"
  end

  def test_add_body_type_headers_when_body_is_nil_on_options_sets_content_length_zero
    io = StringIO.new
    body = HTTP::Request::Body.new(nil)
    writer = build_writer(io: io, body: body, headerstart: "OPTIONS /test HTTP/1.1")
    writer.stream

    assert_includes io.string, "Content-Length: 0"
  end

  # #write (private) partial write handling

  def test_write_partial_writes_exact_correct_bytes_no_duplication
    written_data = +""
    write_calls = 0
    mock_io = Object.new
    mock_io.define_singleton_method(:write) do |data|
      write_calls += 1
      bytes = [2, data.bytesize].min
      written_data << data.byteslice(0, bytes)
      bytes
    end

    body = HTTP::Request::Body.new("ABCDEF")
    headerstart = "GET /test HTTP/1.1"
    w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
    w.stream

    assert_includes written_data, "ABCDEF"
    body_start = written_data.index("ABCDEF")

    refute_nil body_start
    assert_nil written_data.index("ABCDEF", body_start + 1)
    assert_operator write_calls, :>, 1
  end

  def test_write_when_socket_writes_all_bytes_at_once_calls_write_once
    write_calls = 0
    mock_io = Object.new
    mock_io.define_singleton_method(:write) do |data|
      write_calls += 1
      data.bytesize
    end

    body = HTTP::Request::Body.new("Hello")
    w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, "GET /test HTTP/1.1")
    w.stream

    assert_equal 1, write_calls
  end

  def test_write_when_data_is_split_across_two_writes_correctly_slices_remaining
    written_chunks = []
    call_count = 0
    mock_io = Object.new
    mock_io.define_singleton_method(:write) do |data|
      call_count += 1
      written_chunks << data.dup
      if call_count == 1
        [5, data.bytesize].min
      else
        data.bytesize
      end
    end

    body = HTTP::Request::Body.new("TESTDATA123")
    headerstart = "GET /test HTTP/1.1"
    w = HTTP::Request::Writer.new(mock_io, body, HTTP::Headers.new, headerstart)
    w.stream

    full_output = written_chunks.map { |c| c.byteslice(0, [5, c.bytesize].min) }.first +
                  written_chunks[1..].join

    assert_includes full_output, "TESTDATA123"
    assert_operator written_chunks[1].bytesize, :<, written_chunks[0].bytesize
  end
end
