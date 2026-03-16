# frozen_string_literal: true

require "test_helper"

class HTTPConnectionTest < Minitest::Test
  cover "HTTP::Connection*"

  def build_req(uri: "http://example.com/", verb: :get, headers: {}, **)
    HTTP::Request.new(verb: verb, uri: uri, headers: headers, **)
  end

  def build_connection(socket: nil, **)
    socket ||= fake(connect: nil, close: nil)
    timeout_class = fake(new: socket)
    req = build_req
    opts_obj = HTTP::Options.new(timeout_class: timeout_class, **)
    HTTP::Connection.new(req, opts_obj)
  end

  # ---------------------------------------------------------------------------
  # #initialize
  # ---------------------------------------------------------------------------
  def test_initialize_initializes_state_from_options
    connection = build_connection

    refute_predicate connection, :failed_proxy_connect?
    assert_predicate connection, :finished_request?
    assert_predicate connection, :expired?
  end

  def test_initialize_raises_connection_error_on_io_error_during_connect
    req = build_req
    err_socket = fake(
      connect: ->(*) { raise IOError, "connection refused" }
    )
    err_timeout_class = fake(new: err_socket)
    err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

    err = assert_raises(HTTP::ConnectionError) do
      HTTP::Connection.new(req, err_opts)
    end
    assert_includes err.message, "failed to connect"
    assert_includes err.message, "connection refused"
    refute_nil err.backtrace
  end

  def test_initialize_raises_connection_error_on_socket_error_during_connect
    req = build_req
    err_socket = fake(
      connect: ->(*) { raise SocketError, "dns failure" }
    )
    err_timeout_class = fake(new: err_socket)
    err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

    err = assert_raises(HTTP::ConnectionError) do
      HTTP::Connection.new(req, err_opts)
    end
    assert_includes err.message, "failed to connect"
    assert_includes err.message, "dns failure"
  end

  def test_initialize_raises_connection_error_on_system_call_error_during_connect
    req = build_req
    err_socket = fake(
      connect: ->(*) { raise Errno::ECONNREFUSED, "refused" }
    )
    err_timeout_class = fake(new: err_socket)
    err_opts = HTTP::Options.new(timeout_class: err_timeout_class)

    err = assert_raises(HTTP::ConnectionError) do
      HTTP::Connection.new(req, err_opts)
    end
    assert_includes err.message, "failed to connect"
  end

  def test_initialize_timeout_error_closes_socket_and_re_raises
    https_req = build_req(uri: "https://example.com/")
    closed = false
    tls_socket = fake(
      connect:   nil,
      close:     -> { closed = true },
      start_tls: ->(*) { raise HTTP::TimeoutError },
      closed?:   false
    )
    tls_timeout_class = fake(new: tls_socket)
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

    assert_raises(HTTP::TimeoutError) do
      HTTP::Connection.new(https_req, tls_opts)
    end
    assert closed, "socket should have been closed"
  end

  def test_initialize_io_timeout_error_converts_to_connect_timeout_error
    req = build_req
    io_timeout_socket = fake(
      connect: lambda { |*|
        raise IO::TimeoutError, "Connect timed out!"
      },
      close:   nil,
      closed?: false
    )
    io_timeout_class = fake(new: io_timeout_socket)
    io_opts = HTTP::Options.new(timeout_class: io_timeout_class)

    err = assert_raises(HTTP::ConnectTimeoutError) do
      HTTP::Connection.new(req, io_opts)
    end
    assert_equal "Connect timed out!", err.message
  end

  # ---------------------------------------------------------------------------
  # #send_request
  # ---------------------------------------------------------------------------
  def test_send_request_streams_request_and_sets_pending_state
    req = build_req
    sr_req = build_req(uri: "http://example.com/path")

    write_socket = fake(connect: nil, close: nil, write: proc(&:bytesize))
    write_timeout_class = fake(new: write_socket)
    write_opts = HTTP::Options.new(timeout_class: write_timeout_class)
    conn = HTTP::Connection.new(req, write_opts)

    assert_predicate conn, :finished_request?

    conn.send_request(sr_req)

    refute_predicate conn, :finished_request?
    assert conn.instance_variable_get(:@pending_response)
    refute conn.instance_variable_get(:@pending_request)
  end

  def test_send_request_raises_state_error_when_request_already_pending
    connection = build_connection
    connection.instance_variable_set(:@pending_request, true)
    sr_req = build_req
    err = assert_raises(HTTP::StateError) { connection.send_request(sr_req) }
    assert_includes err.message, "response is pending"
  end

  def test_send_request_sets_pending_request_true_before_streaming_then_false_after
    req = build_req
    pending_during_stream = nil
    conn = nil
    stream_socket = fake(
      connect: nil,
      close:   nil,
      write:   proc { |data|
        pending_during_stream = conn.instance_variable_get(:@pending_request)
        data.bytesize
      }
    )
    stream_timeout_class = fake(new: stream_socket)
    stream_opts = HTTP::Options.new(timeout_class: stream_timeout_class)
    conn = HTTP::Connection.new(req, stream_opts)

    sr_req = build_req
    conn.send_request(sr_req)

    assert pending_during_stream, "pending_request should be true during streaming"
    assert conn.instance_variable_get(:@pending_response)
    refute conn.instance_variable_get(:@pending_request)
  end

  def test_send_request_calls_req_stream_with_socket
    req = build_req
    stream_args = nil
    sr_req = Minitest::Mock.new
    sr_req.expect(:stream, nil) do |s|
      stream_args = s
      true
    end

    write_socket = fake(connect: nil, close: nil, write: lambda(&:bytesize))
    write_timeout_class = fake(new: write_socket)
    write_opts = HTTP::Options.new(timeout_class: write_timeout_class)
    conn = HTTP::Connection.new(req, write_opts)

    conn.send_request(sr_req)

    assert_same conn.instance_variable_get(:@socket), stream_args
    sr_req.verify
  end

  # ---------------------------------------------------------------------------
  # #readpartial
  # ---------------------------------------------------------------------------
  def test_readpartial_raises_eof_error_when_no_response_pending
    connection = build_connection

    assert_raises(EOFError) { connection.readpartial }
  end

  def test_readpartial_reads_data_from_socket_and_returns_chunks
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      :eof
    ]
    rp_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { call_count >= responses.length }
    )
    rp_timeout_class = fake(new: rp_socket)
    rp_opts = HTTP::Options.new(timeout_class: rp_timeout_class)
    conn = HTTP::Connection.new(req, rp_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial

    assert_equal "hello", chunk
  end

  def test_readpartial_reads_data_in_parts_and_finishes
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Type: text\r\n\r\n",
      "1", "23", "456", "78", "9", "0", :eof
    ]
    rp_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { call_count >= responses.length }
    )
    rp_timeout_class = fake(new: rp_socket)
    rp_opts = HTTP::Options.new(timeout_class: rp_timeout_class)
    conn = HTTP::Connection.new(req, rp_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    buffer = +""
    begin
      loop do
        s = conn.readpartial(3)
        refute_predicate conn, :finished_request? if s != ""
        buffer << s
      end
    rescue EOFError
      # Expected
    end

    assert_equal "1234567890", buffer
    assert_predicate conn, :finished_request?
  end

  def test_readpartial_fills_outbuf_when_provided
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      :eof
    ]
    ob_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { call_count >= responses.length }
    )
    ob_timeout_class = fake(new: ob_socket)
    ob_opts = HTTP::Options.new(timeout_class: ob_timeout_class)
    conn = HTTP::Connection.new(req, ob_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    outbuf = +""
    result = conn.readpartial(16_384, outbuf)

    assert_equal "hello", outbuf
    assert_same outbuf, result
  end

  def test_readpartial_uses_size_parameter_when_reading_from_socket
    req = build_req
    call_count = 0
    read_sizes = []
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n",
      "helloworld",
      :eof
    ]
    sz_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc { |size, *|
        read_sizes << size
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { call_count >= responses.length }
    )
    sz_timeout_class = fake(new: sz_socket)
    sz_opts = HTTP::Options.new(timeout_class: sz_timeout_class)
    conn = HTTP::Connection.new(req, sz_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    conn.readpartial(42)

    assert_includes read_sizes, 42
  end

  def test_readpartial_detects_premature_eof_on_framed_content_length_response
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nhello",
      :eof
    ]
    eof_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    eof_timeout_class = fake(new: eof_socket)
    eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
    conn = HTTP::Connection.new(req, eof_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial

    assert_equal "hello", chunk
    err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
    assert_includes err.message, "response body ended prematurely"
  end

  def test_readpartial_detects_premature_eof_on_chunked_response
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n",
      :eof
    ]
    eof_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    eof_timeout_class = fake(new: eof_socket)
    eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
    conn = HTTP::Connection.new(req, eof_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial

    assert_equal "hello", chunk
    err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
    assert_includes err.message, "response body ended prematurely"
  end

  def test_readpartial_finishes_cleanly_when_not_framed
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\n\r\nhello",
      :eof
    ]
    unframed_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    unframed_timeout_class = fake(new: unframed_socket)
    unframed_opts = HTTP::Options.new(timeout_class: unframed_timeout_class)
    conn = HTTP::Connection.new(req, unframed_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial

    assert_equal "hello", chunk
    # Should not raise premature EOF because body is not framed
    chunk2 = conn.readpartial

    assert_equal "", chunk2
  end

  def test_readpartial_finishes_response_when_parser_says_finished
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n",
      "hello",
      # After reading "hello", parser is finished (Content-Length satisfied)
      # even if we haven't seen :eof yet
      "more data that shouldn't matter",
      :eof
    ]
    pf_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    pf_timeout_class = fake(new: pf_socket)
    pf_opts = HTTP::Options.new(timeout_class: pf_timeout_class)
    conn = HTTP::Connection.new(req, pf_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial

    assert_equal "hello", chunk
    # After reading exactly Content-Length bytes, parser.finished? should be true
    # and finish_response should be called
    assert_predicate conn, :finished_request?
  end

  def test_readpartial_returns_binary_empty_string_when_parser_has_no_data
    req = build_req
    call_count = 0
    # Headers with no body data, then immediately EOF
    responses = [
      "HTTP/1.1 200 OK\r\n\r\n",
      :eof
    ]
    empty_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    empty_timeout_class = fake(new: empty_socket)
    empty_opts = HTTP::Options.new(timeout_class: empty_timeout_class)
    conn = HTTP::Connection.new(req, empty_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    chunk = conn.readpartial
    # Should return binary empty string "".b
    assert_equal Encoding::ASCII_8BIT, chunk.encoding
  end

  # ---------------------------------------------------------------------------
  # #read_headers!
  # ---------------------------------------------------------------------------
  def test_read_headers_populates_headers_preserving_casing
    req = build_req
    raw_response = "HTTP/1.1 200 OK\r\nContent-Type: text\r\nfoo_bar: 123\r\n\r\n"
    read_socket = fake(connect: nil, close: nil, readpartial: raw_response)
    read_timeout_class = fake(new: read_socket)
    read_opts = HTTP::Options.new(timeout_class: read_timeout_class)
    conn = HTTP::Connection.new(req, read_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!

    assert_equal "text", conn.headers["Content-Type"]
    assert_equal "123", conn.headers["Foo-Bar"]
    assert_equal "123", conn.headers["foo_bar"]
  end

  def test_read_headers_raises_response_header_error_on_eof_before_headers_complete
    req = build_req
    eof_socket = fake(connect: nil, close: nil, readpartial: :eof)
    eof_timeout_class = fake(new: eof_socket)
    eof_opts = HTTP::Options.new(timeout_class: eof_timeout_class)
    conn = HTTP::Connection.new(req, eof_opts)
    conn.instance_variable_set(:@pending_response, true)

    err = assert_raises(HTTP::ResponseHeaderError) { conn.read_headers! }
    assert_includes err.message, "couldn't read response headers"
  end

  def test_read_headers_calls_set_keep_alive_after_reading
    req = build_req
    raw_response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
    read_socket = fake(connect: nil, close: nil, readpartial: raw_response, closed?: false)
    read_timeout_class = fake(new: read_socket)
    read_opts = HTTP::Options.new(timeout_class: read_timeout_class)
    conn = HTTP::Connection.new(req, read_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    assert_predicate conn, :keep_alive?
  end

  def test_read_headers_passes_buffer_size_to_read_more
    req = build_req
    read_sizes = []
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      :eof
    ]
    bs_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc { |size, *|
        read_sizes << size
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      }
    )
    bs_timeout_class = fake(new: bs_socket)
    bs_opts = HTTP::Options.new(timeout_class: bs_timeout_class)
    conn = HTTP::Connection.new(req, bs_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!

    assert_includes read_sizes, HTTP::Connection::BUFFER_SIZE
  end

  # ---------------------------------------------------------------------------
  # #read_headers! with 1xx informational response
  # ---------------------------------------------------------------------------
  def test_read_headers_skips_100_continue_and_returns_final_response
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      :eof
    ]
    info_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      }
    )
    info_timeout_class = fake(new: info_socket)
    info_opts = HTTP::Options.new(timeout_class: info_timeout_class)
    conn = HTTP::Connection.new(req, info_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!

    assert_equal 200, conn.status_code
    assert_equal "5", conn.headers["Content-Length"]
  end

  def test_read_headers_skips_100_continue_in_small_chunks
    req = build_req
    raw = "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
    chunks = raw.chars + [:eof]
    call_count = 0
    chunked_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, chunks.length - 1].min
        chunks[idx].tap { call_count += 1 }
      }
    )
    chunked_timeout_class = fake(new: chunked_socket)
    chunked_opts = HTTP::Options.new(timeout_class: chunked_timeout_class)
    conn = HTTP::Connection.new(req, chunked_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!

    assert_equal 200, conn.status_code
    assert_equal "5", conn.headers["Content-Length"]
  end

  # ---------------------------------------------------------------------------
  # #send_request when response already pending
  # ---------------------------------------------------------------------------
  def test_send_request_with_pending_response_boolean_closes_and_proceeds
    req = build_req
    socket = fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize))
    timeout_class = fake(new: socket)
    opts = HTTP::Options.new(timeout_class: timeout_class)
    connection = HTTP::Connection.new(req, opts)
    connection.instance_variable_set(:@pending_response, true)
    new_req = build_req
    connection.send_request(new_req)

    assert connection.instance_variable_get(:@pending_response)
  end

  def test_send_request_with_large_content_length_pending_closes_instead_of_flushing
    req = build_req
    socket = fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize))
    timeout_class = fake(new: socket)
    opts = HTTP::Options.new(timeout_class: timeout_class)
    connection = HTTP::Connection.new(req, opts)
    response = fake(content_length: HTTP::Connection::MAX_FLUSH_SIZE + 1, flush: nil)
    connection.instance_variable_set(:@pending_response, response)
    new_req = build_req
    connection.send_request(new_req)

    assert connection.instance_variable_get(:@pending_response)
  end

  def test_send_request_when_flushing_raises_closes_and_proceeds
    req = build_req
    socket = fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize))
    timeout_class = fake(new: socket)
    opts = HTTP::Options.new(timeout_class: timeout_class)
    connection = HTTP::Connection.new(req, opts)
    response = fake(content_length: nil, flush: -> { raise "boom" })
    connection.instance_variable_set(:@pending_response, response)
    new_req = build_req
    connection.send_request(new_req)

    assert connection.instance_variable_get(:@pending_response)
  end

  def test_send_request_with_small_body_pending_flushes_response_body
    req = build_req
    socket = fake(connect: nil, close: nil, closed?: false, write: lambda(&:bytesize))
    timeout_class = fake(new: socket)
    opts = HTTP::Options.new(timeout_class: timeout_class)
    connection = HTTP::Connection.new(req, opts)
    flushed = false
    response = fake(content_length: 100, flush: -> { flushed = true })
    connection.instance_variable_set(:@pending_response, response)
    new_req = build_req
    connection.send_request(new_req)

    assert flushed
  end

  # ---------------------------------------------------------------------------
  # #finish_response
  # ---------------------------------------------------------------------------
  def test_finish_response_closes_socket_when_not_keeping_alive
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      :eof
    ]
    closed = false
    fr_socket = fake(
      connect:     nil,
      close:       -> { closed = true },
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { closed }
    )
    fr_timeout_class = fake(new: fr_socket)
    fr_opts = HTTP::Options.new(timeout_class: fr_timeout_class)
    conn = HTTP::Connection.new(req, fr_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    conn.finish_response

    assert closed, "socket should be closed when not keep-alive"
    assert_predicate conn, :finished_request?
  end

  def test_finish_response_does_not_close_socket_when_keeping_alive
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      :eof
    ]
    closed = false
    ka_socket = fake(
      connect:     nil,
      close:       -> { closed = true },
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     proc { closed }
    )
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class, keep_alive_timeout: 10)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    assert_predicate conn, :keep_alive?
    conn.finish_response

    refute closed, "socket should NOT be closed when keep-alive"
    assert_predicate conn, :finished_request?
  end

  def test_finish_response_resets_parser_for_reuse
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      :eof
    ]
    pr_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    pr_timeout_class = fake(new: pr_socket)
    pr_opts = HTTP::Options.new(timeout_class: pr_timeout_class)
    conn = HTTP::Connection.new(req, pr_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    assert_equal 200, conn.status_code

    conn.finish_response

    # Parser should be reset -- feeding new response should work
    parser = conn.instance_variable_get(:@parser)
    parser << "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"

    assert_equal 404, conn.status_code
  end

  def test_finish_response_calls_reset_counter_when_socket_responds_to_it
    req = build_req
    counter_reset = false
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      :eof
    ]
    rc_socket = fake(
      connect:       nil,
      close:         nil,
      readpartial:   proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:       false,
      reset_counter: -> { counter_reset = true }
    )
    rc_timeout_class = fake(new: rc_socket)
    rc_opts = HTTP::Options.new(timeout_class: rc_timeout_class)
    conn = HTTP::Connection.new(req, rc_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!
    conn.finish_response

    assert counter_reset, "reset_counter should have been called"
  end

  def test_finish_response_does_not_call_reset_counter_when_socket_does_not_respond
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      :eof
    ]
    # Socket without reset_counter method
    no_rc_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    no_rc_timeout_class = fake(new: no_rc_socket)
    no_rc_opts = HTTP::Options.new(timeout_class: no_rc_timeout_class)
    conn = HTTP::Connection.new(req, no_rc_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!
    # Should not raise even though socket lacks reset_counter
    conn.finish_response

    assert_predicate conn, :finished_request?
  end

  def test_finish_response_resets_timer_for_persistent_connections
    req = build_req
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      :eof
    ]
    rt_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    rt_timeout_class = fake(new: rt_socket)
    rt_opts = HTTP::Options.new(timeout_class: rt_timeout_class, keep_alive_timeout: 30)
    conn = HTTP::Connection.new(req, rt_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    before = Time.now
    conn.finish_response
    after = Time.now

    expires = conn.instance_variable_get(:@conn_expires_at)

    assert_operator expires, :>=, before + 30
    assert_operator expires, :<=, after + 30
  end

  # ---------------------------------------------------------------------------
  # #close
  # ---------------------------------------------------------------------------
  def test_close_when_socket_is_nil_raises_no_method_error
    conn = HTTP::Connection.allocate
    conn.instance_variable_set(:@socket, nil)
    conn.instance_variable_set(:@pending_response, false)
    conn.instance_variable_set(:@pending_request, false)
    assert_raises(NoMethodError) { conn.close }
  end

  def test_close_closes_socket_and_clears_pending_state
    req = build_req
    closed = false
    close_socket = fake(
      connect: nil,
      close:   -> { closed = true },
      closed?: proc { closed }
    )
    close_timeout_class = fake(new: close_socket)
    close_opts = HTTP::Options.new(timeout_class: close_timeout_class)
    conn = HTTP::Connection.new(req, close_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@pending_request, true)

    conn.close

    assert closed, "socket should be closed"
    refute conn.instance_variable_get(:@pending_response)
    refute conn.instance_variable_get(:@pending_request)
  end

  def test_close_does_not_close_already_closed_socket
    req = build_req
    close_count = 0
    already_closed_socket = fake(
      connect: nil,
      close:   -> { close_count += 1 },
      closed?: true
    )
    ac_timeout_class = fake(new: already_closed_socket)
    ac_opts = HTTP::Options.new(timeout_class: ac_timeout_class)
    conn = HTTP::Connection.new(req, ac_opts)

    conn.close

    assert_equal 0, close_count
  end

  # ---------------------------------------------------------------------------
  # #finished_request?
  # ---------------------------------------------------------------------------
  def test_finished_request_returns_true_when_neither_pending
    connection = build_connection

    assert_predicate connection, :finished_request?
  end

  def test_finished_request_returns_false_when_pending_response
    connection = build_connection
    connection.instance_variable_set(:@pending_response, true)

    refute_predicate connection, :finished_request?
  end

  def test_finished_request_returns_false_when_pending_request
    connection = build_connection
    connection.instance_variable_set(:@pending_request, true)

    refute_predicate connection, :finished_request?
  end

  def test_finished_request_returns_false_when_both_pending
    connection = build_connection
    connection.instance_variable_set(:@pending_request, true)
    connection.instance_variable_set(:@pending_response, true)

    refute_predicate connection, :finished_request?
  end

  # ---------------------------------------------------------------------------
  # #keep_alive?
  # ---------------------------------------------------------------------------
  def test_keep_alive_returns_false_when_keep_alive_is_false
    connection = build_connection
    connection.instance_variable_set(:@keep_alive, false)

    refute_predicate connection, :keep_alive?
  end

  def test_keep_alive_returns_false_when_socket_is_closed
    req = build_req
    closed_socket = fake(connect: nil, close: nil, closed?: true)
    closed_timeout_class = fake(new: closed_socket)
    closed_opts = HTTP::Options.new(timeout_class: closed_timeout_class)
    conn = HTTP::Connection.new(req, closed_opts)
    conn.instance_variable_set(:@keep_alive, true)

    refute_predicate conn, :keep_alive?
  end

  def test_keep_alive_returns_true_when_keep_alive_and_socket_open
    req = build_req
    open_socket = fake(connect: nil, close: nil, closed?: false)
    open_timeout_class = fake(new: open_socket)
    open_opts = HTTP::Options.new(timeout_class: open_timeout_class)
    conn = HTTP::Connection.new(req, open_opts)
    conn.instance_variable_set(:@keep_alive, true)

    assert_predicate conn, :keep_alive?
  end

  # ---------------------------------------------------------------------------
  # #expired?
  # ---------------------------------------------------------------------------
  def test_expired_returns_true_when_conn_expires_at_is_nil
    connection = build_connection

    assert_predicate connection, :expired?
  end

  def test_expired_returns_true_when_connection_has_expired
    connection = build_connection
    connection.instance_variable_set(:@conn_expires_at, Time.now - 1)

    assert_predicate connection, :expired?
  end

  def test_expired_returns_false_when_connection_has_not_expired
    connection = build_connection
    connection.instance_variable_set(:@conn_expires_at, Time.now + 60)

    refute_predicate connection, :expired?
  end

  # ---------------------------------------------------------------------------
  # keep_alive behavior (set_keep_alive)
  # ---------------------------------------------------------------------------
  def test_keep_alive_with_http10_and_keep_alive_header
    req = build_req
    response = "HTTP/1.0 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    assert_predicate conn, :keep_alive?
  end

  def test_keep_alive_with_http10_without_keep_alive_header
    req = build_req
    response = "HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    refute_predicate conn, :keep_alive?
  end

  def test_keep_alive_with_http11_and_no_connection_header
    req = build_req
    response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    assert_predicate conn, :keep_alive?
  end

  def test_keep_alive_with_http11_and_connection_close
    req = build_req
    response = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    refute_predicate conn, :keep_alive?
  end

  def test_keep_alive_with_unknown_http_version
    req = build_req
    response = "HTTP/2.0 200 OK\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)
    conn.instance_variable_set(:@persistent, true)

    conn.read_headers!

    refute_predicate conn, :keep_alive?
  end

  def test_keep_alive_when_not_persistent_sets_keep_alive_false
    req = build_req
    response = "HTTP/1.1 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: 2\r\n\r\nOK"
    ka_socket = fake(connect: nil, close: nil, readpartial: response, closed?: false)
    ka_timeout_class = fake(new: ka_socket)
    ka_opts = HTTP::Options.new(timeout_class: ka_timeout_class)
    conn = HTTP::Connection.new(req, ka_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!

    refute_predicate conn, :keep_alive?
  end

  # ---------------------------------------------------------------------------
  # proxy connect
  # ---------------------------------------------------------------------------
  def test_proxy_connect_non_200_marks_failed_and_stores_headers
    proxy_req = build_req(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    proxy_response = "HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic\r\n\r\n"
    call_count = 0
    proxy_socket = fake(
      connect:     nil,
      close:       nil,
      write:       lambda(&:bytesize),
      readpartial: proc {
        call_count += 1
        call_count == 1 ? proxy_response : :eof
      },
      start_tls:   ->(*) {}
    )
    proxy_timeout_class = fake(new: proxy_socket)
    proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)
    conn = HTTP::Connection.new(proxy_req, proxy_opts)

    assert_predicate conn, :failed_proxy_connect?
    assert_instance_of HTTP::Headers, conn.proxy_response_headers
    assert_equal "Basic", conn.proxy_response_headers["Proxy-Authenticate"]
    # pending_response should still be true (not reset on failure)
    assert conn.instance_variable_get(:@pending_response)
  end

  def test_proxy_connect_200_completes_successfully_and_resets_parser
    proxy_req = build_req(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    proxy_response = "HTTP/1.1 200 Connection established\r\n\r\n"
    proxy_socket = fake(
      connect:               nil,
      close:                 nil,
      write:                 lambda(&:bytesize),
      readpartial:           proxy_response,
      start_tls:             ->(*) {},
      "hostname=":           ->(*) {},
      "sync_close=":         ->(*) {},
      post_connection_check: ->(*) {}
    )
    proxy_timeout_class = fake(new: proxy_socket)
    proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)
    conn = HTTP::Connection.new(proxy_req, proxy_opts)

    refute_predicate conn, :failed_proxy_connect?
    assert_instance_of HTTP::Headers, conn.proxy_response_headers
    # Parser should have been reset, pending_response should be false
    assert_predicate conn, :finished_request?
  end

  def test_proxy_connect_skips_for_http_request
    http_proxy_req = build_req(
      uri:   "http://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    connect_called = false
    plain_socket = fake(
      connect:             nil,
      close:               nil,
      connect_using_proxy: ->(*) { connect_called = true }
    )
    plain_timeout_class = fake(new: plain_socket)
    plain_opts = HTTP::Options.new(timeout_class: plain_timeout_class)
    conn = HTTP::Connection.new(http_proxy_req, plain_opts)

    refute connect_called
    refute_predicate conn, :failed_proxy_connect?
  end

  # ---------------------------------------------------------------------------
  # start_tls
  # ---------------------------------------------------------------------------
  def test_start_tls_uses_provided_ssl_context
    ssl_ctx = OpenSSL::SSL::SSLContext.new
    https_req = build_req(uri: "https://example.com/")

    start_tls_args = nil
    tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*args) { start_tls_args = args }
    )
    tls_timeout_class = fake(new: tls_socket)
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl_context: ssl_ctx)

    HTTP::Connection.new(https_req, tls_opts)

    assert_equal "example.com", start_tls_args[0]
    assert_equal ssl_ctx, start_tls_args[2]
  end

  def test_start_tls_creates_ssl_context_when_not_provided
    https_req = build_req(uri: "https://example.com/")

    start_tls_args = nil
    tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*args) { start_tls_args = args }
    )
    tls_timeout_class = fake(new: tls_socket)
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

    HTTP::Connection.new(https_req, tls_opts)

    assert_equal "example.com", start_tls_args[0]
    assert_instance_of OpenSSL::SSL::SSLContext, start_tls_args[2]
  end

  def test_start_tls_passes_ssl_socket_class
    https_req = build_req(uri: "https://example.com/")

    start_tls_args = nil
    tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*args) { start_tls_args = args }
    )
    tls_timeout_class = fake(new: tls_socket)
    custom_ssl_class = Class.new
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl_socket_class: custom_ssl_class)

    HTTP::Connection.new(https_req, tls_opts)

    assert_equal custom_ssl_class, start_tls_args[1]
  end

  def test_start_tls_passes_host_from_req_uri_host
    https_req = build_req(uri: "https://subdomain.example.com/")

    start_tls_args = nil
    tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*args) { start_tls_args = args }
    )
    tls_timeout_class = fake(new: tls_socket)
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class)

    HTTP::Connection.new(https_req, tls_opts)

    assert_equal "subdomain.example.com", start_tls_args[0]
  end

  def test_start_tls_skips_tls_for_http_requests
    http_req = build_req(uri: "http://example.com/")
    start_tls_called = false
    no_tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*) { start_tls_called = true }
    )
    no_tls_timeout_class = fake(new: no_tls_socket)
    no_tls_opts = HTTP::Options.new(timeout_class: no_tls_timeout_class)

    HTTP::Connection.new(http_req, no_tls_opts)

    refute start_tls_called
  end

  def test_start_tls_skips_tls_when_proxy_connect_failed
    proxy_req = build_req(
      uri:   "https://example.com/",
      proxy: { proxy_address: "proxy.example.com", proxy_port: 8080 }
    )
    proxy_response = "HTTP/1.1 407 Auth Required\r\nContent-Length: 0\r\n\r\n"
    call_count = 0
    start_tls_called = false
    proxy_socket = fake(
      connect:     nil,
      close:       nil,
      write:       lambda(&:bytesize),
      readpartial: proc {
        call_count += 1
        call_count == 1 ? proxy_response : :eof
      },
      start_tls:   ->(*) { start_tls_called = true }
    )
    proxy_timeout_class = fake(new: proxy_socket)
    proxy_opts = HTTP::Options.new(timeout_class: proxy_timeout_class)

    conn = HTTP::Connection.new(proxy_req, proxy_opts)

    assert_predicate conn, :failed_proxy_connect?
    refute start_tls_called
  end

  def test_start_tls_applies_ssl_options_via_set_params_when_no_ssl_context
    https_req = build_req(uri: "https://example.com/")

    start_tls_args = nil
    tls_socket = fake(
      connect:   nil,
      close:     nil,
      start_tls: ->(*args) { start_tls_args = args }
    )
    tls_timeout_class = fake(new: tls_socket)
    ssl_options = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    tls_opts = HTTP::Options.new(timeout_class: tls_timeout_class, ssl: ssl_options)

    HTTP::Connection.new(https_req, tls_opts)

    ctx = start_tls_args[2]

    assert_instance_of OpenSSL::SSL::SSLContext, ctx
    assert_equal OpenSSL::SSL::VERIFY_NONE, ctx.verify_mode
  end

  # ---------------------------------------------------------------------------
  # read_more and error handling
  # ---------------------------------------------------------------------------
  def test_read_more_handles_nil_from_readpartial
    req = build_req
    call_count = 0
    responses = ["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", nil, :eof]
    rm_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc { responses[[call_count, responses.length - 1].min].tap { call_count += 1 } }
    )
    rm_timeout_class = fake(new: rm_socket)
    rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
    conn = HTTP::Connection.new(req, rm_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    result = conn.readpartial

    assert_equal "", result
  end

  def test_read_more_raises_socket_read_error_on_io_errors
    req = build_req
    call_count = 0
    rm_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        call_count += 1
        raise IOError, "broken" unless call_count == 1

        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
      }
    )
    rm_timeout_class = fake(new: rm_socket)
    rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
    conn = HTTP::Connection.new(req, rm_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
    assert_includes err.message, "error reading from socket"
    assert_includes err.message, "broken"
  end

  def test_read_more_raises_socket_read_error_on_socket_error
    req = build_req
    call_count = 0
    rm_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc {
        call_count += 1
        raise SocketError, "socket error" unless call_count == 1

        "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
      }
    )
    rm_timeout_class = fake(new: rm_socket)
    rm_opts = HTTP::Options.new(timeout_class: rm_timeout_class)
    conn = HTTP::Connection.new(req, rm_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    err = assert_raises(HTTP::ConnectionError) { conn.readpartial }
    assert_includes err.message, "error reading from socket"
    assert_includes err.message, "socket error"
  end

  def test_read_more_passes_buffer_to_socket_readpartial
    req = build_req
    read_args = []
    call_count = 0
    responses = [
      "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n",
      "hello",
      :eof
    ]
    buf_socket = fake(
      connect:     nil,
      close:       nil,
      readpartial: proc { |*args|
        read_args << args
        idx = [call_count, responses.length - 1].min
        responses[idx].tap { call_count += 1 }
      },
      closed?:     false
    )
    buf_timeout_class = fake(new: buf_socket)
    buf_opts = HTTP::Options.new(timeout_class: buf_timeout_class)
    conn = HTTP::Connection.new(req, buf_opts)
    conn.instance_variable_set(:@pending_response, true)

    conn.read_headers!
    conn.readpartial

    # Verify that readpartial was called with 2 arguments (size + buffer)
    assert(read_args.all? { |a| a.length == 2 }, "readpartial should receive size and buffer")
    # Verify the buffer is a string (not nil)
    assert(read_args.all? { |a| a[1].is_a?(String) }, "buffer should be a String")
  end

  # ---------------------------------------------------------------------------
  # connect_socket
  # ---------------------------------------------------------------------------
  def test_connect_socket_passes_correct_arguments
    req = build_req
    connect_args = nil
    connect_kwargs = nil
    cs_socket = fake(
      connect: lambda { |*args, **kwargs|
        connect_args = args
        connect_kwargs = kwargs
      },
      close:   nil
    )
    cs_timeout_class = fake(new: cs_socket)
    cs_opts = HTTP::Options.new(timeout_class: cs_timeout_class)

    HTTP::Connection.new(req, cs_opts)

    assert_equal HTTP::Options.default_socket_class, connect_args[0]
    assert_equal "example.com", connect_args[1]
    assert_equal 80, connect_args[2]
    refute connect_kwargs.fetch(:nodelay)
  end

  def test_connect_socket_passes_timeout_options_to_timeout_class_new
    req = build_req
    new_kwargs = nil
    cs_socket = fake(connect: nil, close: nil)
    cs_timeout_class = fake(
      new: lambda { |**kwargs|
        new_kwargs = kwargs
        cs_socket
      }
    )
    cs_opts = HTTP::Options.new(timeout_class: cs_timeout_class)

    HTTP::Connection.new(req, cs_opts)

    assert_instance_of Hash, new_kwargs
  end

  def test_connect_socket_calls_reset_timer_during_initialization
    req = build_req
    persist_socket = fake(connect: nil, close: nil)
    persist_timeout_class = fake(new: persist_socket)
    persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 5)
    conn = HTTP::Connection.new(req, persist_opts)
    conn.instance_variable_set(:@persistent, true)

    # For persistent connections, reset_timer should set @conn_expires_at
    before = Time.now
    conn.send(:reset_timer)
    after = Time.now

    expires = conn.instance_variable_get(:@conn_expires_at)

    assert_operator expires, :>=, before + 5
    assert_operator expires, :<=, after + 5
  end

  # ---------------------------------------------------------------------------
  # reset_timer
  # ---------------------------------------------------------------------------
  def test_reset_timer_sets_conn_expires_at_for_persistent_connections
    req = build_req
    persist_socket = fake(connect: nil, close: nil)
    persist_timeout_class = fake(new: persist_socket)
    persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 5)
    conn = HTTP::Connection.new(req, persist_opts)
    conn.instance_variable_set(:@persistent, true)

    before = Time.now
    conn.send(:reset_timer)
    after = Time.now

    expires = conn.instance_variable_get(:@conn_expires_at)

    assert_operator expires, :>=, before + 5
    assert_operator expires, :<=, after + 5
  end

  def test_reset_timer_does_not_set_conn_expires_at_for_non_persistent
    connection = build_connection
    connection.instance_variable_set(:@conn_expires_at, nil)
    connection.send(:reset_timer)

    assert_nil connection.instance_variable_get(:@conn_expires_at)
  end

  def test_reset_timer_uses_keep_alive_timeout_from_options
    req = build_req
    persist_socket = fake(connect: nil, close: nil)
    persist_timeout_class = fake(new: persist_socket)
    persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, keep_alive_timeout: 42)
    conn = HTTP::Connection.new(req, persist_opts)
    conn.instance_variable_set(:@persistent, true)

    before = Time.now
    conn.send(:reset_timer)

    expires = conn.instance_variable_get(:@conn_expires_at)
    # Should be approximately now + 42
    assert_operator expires, :>=, before + 42
    assert_operator expires, :<, before + 43
  end

  # ---------------------------------------------------------------------------
  # init_state
  # ---------------------------------------------------------------------------
  def test_init_state_stores_persistent_flag_from_options
    req = build_req
    persist_socket = fake(connect: nil, close: nil)
    persist_timeout_class = fake(new: persist_socket)
    persist_opts = HTTP::Options.new(timeout_class: persist_timeout_class, persistent: "http://example.com")
    conn = HTTP::Connection.new(req, persist_opts)

    assert conn.instance_variable_get(:@persistent)
  end

  def test_init_state_stores_keep_alive_timeout_as_float
    connection = build_connection
    kat = connection.instance_variable_get(:@keep_alive_timeout)

    assert_instance_of Float, kat
  end

  def test_init_state_initializes_buffer_as_binary_empty_string
    connection = build_connection
    buf = connection.instance_variable_get(:@buffer)

    assert_equal "".b, buf
    assert_equal Encoding::ASCII_8BIT, buf.encoding
  end

  def test_init_state_initializes_parser
    connection = build_connection
    parser = connection.instance_variable_get(:@parser)

    assert_instance_of HTTP::Response::Parser, parser
  end
end
