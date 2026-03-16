# frozen_string_literal: true

require "test_helper"

class HTTPTimeoutGlobalTest < Minitest::Test
  cover "HTTP::Timeout::Global*"

  def setup
    super
    @io = fake(wait_readable: true, wait_writable: true)
    @socket = fake(to_io: @io, closed?: false)
    @timeout = HTTP::Timeout::Global.new(global_timeout: 5)
    @timeout.instance_variable_set(:@socket, @socket)
  end

  # -- #connect --

  def test_connect_sets_tcp_nodelay_when_nodelay_is_true
    setsockopt_args = nil
    tcp_socket = fake(
      setsockopt: ->(*args) { setsockopt_args = args }
    )

    socket_class = fake(open: tcp_socket)
    @timeout.connect(socket_class, "example.com", 80, nodelay: true)

    assert_equal [Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1], setsockopt_args
  end

  # -- #connect_ssl --

  def test_connect_ssl_completes_without_error
    connected = Object.new
    socket = fake(
      to_io:            @io,
      closed?:          false,
      connect_nonblock: ->(*) { connected }
    )
    @timeout.instance_variable_set(:@socket, socket)
    @timeout.connect_ssl
  end

  def test_connect_ssl_when_wait_readable_raised_waits_and_retries
    call_count = 0
    connected = Object.new
    socket = fake(
      to_io:            @io,
      closed?:          false,
      connect_nonblock: proc { |*|
        call_count += 1
        raise IO::EAGAINWaitReadable if call_count == 1

        connected
      }
    )
    @timeout.instance_variable_set(:@socket, socket)
    @timeout.connect_ssl
  end

  def test_connect_ssl_when_wait_writable_raised_waits_and_retries
    call_count = 0
    connected = Object.new
    socket = fake(
      to_io:            @io,
      closed?:          false,
      connect_nonblock: proc { |*|
        call_count += 1
        raise IO::EAGAINWaitWritable if call_count == 1

        connected
      }
    )
    @timeout.instance_variable_set(:@socket, socket)
    @timeout.connect_ssl
  end

  # -- #perform_io (via readpartial) --

  def test_readpartial_when_wait_readable_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: proc { |*|
        call_count += 1
        call_count == 1 ? :wait_readable : "data"
      }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal "data", @timeout.readpartial(10)
  end

  def test_write_when_wait_writable_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:          @io,
      closed?:        false,
      write_nonblock: proc { |*|
        call_count += 1
        call_count == 1 ? :wait_writable : 4
      }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal 4, @timeout.write("data")
  end

  def test_readpartial_when_io_wait_readable_raised_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: proc { |*|
        call_count += 1
        raise IO::EAGAINWaitReadable if call_count == 1

        "data"
      }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal "data", @timeout.readpartial(10)
  end

  def test_write_when_io_wait_writable_raised_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:          @io,
      closed?:        false,
      write_nonblock: proc { |*|
        call_count += 1
        raise IO::EAGAINWaitWritable if call_count == 1

        4
      }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal 4, @timeout.write("data")
  end

  def test_readpartial_when_nil_eof_returns_eof
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: nil
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal :eof, @timeout.readpartial(10)
  end

  def test_readpartial_when_eof_error_raised_returns_eof
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: ->(*) { raise EOFError }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal :eof, @timeout.readpartial(10)
  end

  # -- with per-operation timeouts --

  def test_readpartial_with_per_op_timeouts_uses_global_time_left_as_effective_timeout
    timeout = HTTP::Timeout::Global.new(global_timeout: 100, read_timeout: 100, write_timeout: 100,
                                        connect_timeout: 100)
    call_count = 0
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: proc { |*|
        call_count += 1
        call_count == 1 ? :wait_readable : "data"
      }
    )
    timeout.instance_variable_set(:@socket, socket)

    assert_equal "data", timeout.readpartial(10)
  end

  def test_readpartial_with_tight_per_op_raises_when_read_timeout_fires
    timeout = HTTP::Timeout::Global.new(global_timeout: 100, read_timeout: 0.01, write_timeout: 0.01,
                                        connect_timeout: 0.01)
    io_nil = fake(wait_readable: nil, wait_writable: true)
    socket = fake(
      to_io:         io_nil,
      closed?:       false,
      read_nonblock: :wait_readable
    )
    timeout.instance_variable_set(:@socket, socket)

    err = assert_raises(HTTP::TimeoutError) { timeout.readpartial(10) }
    assert_match(/Read timed out/, err.message)
  end

  def test_write_with_tight_per_op_raises_when_write_timeout_fires
    timeout = HTTP::Timeout::Global.new(global_timeout: 100, read_timeout: 0.01, write_timeout: 0.01,
                                        connect_timeout: 0.01)
    io_nil = fake(wait_readable: true, wait_writable: nil)
    socket = fake(
      to_io:          io_nil,
      closed?:        false,
      write_nonblock: :wait_writable
    )
    timeout.instance_variable_set(:@socket, socket)

    err = assert_raises(HTTP::TimeoutError) { timeout.write("data") }
    assert_match(/Write timed out/, err.message)
  end

  def test_connect_ssl_with_tight_per_op_uses_connect_timeout_for_wait_readable
    timeout = HTTP::Timeout::Global.new(global_timeout: 100, read_timeout: 0.01, write_timeout: 0.01,
                                        connect_timeout: 0.01)
    io_nil = fake(wait_readable: nil, wait_writable: true)
    socket = fake(
      to_io:            io_nil,
      closed?:          false,
      connect_nonblock: ->(*) { raise IO::EAGAINWaitReadable }
    )
    timeout.instance_variable_set(:@socket, socket)
    assert_raises(HTTP::TimeoutError) { timeout.connect_ssl }
  end

  def test_connect_ssl_with_tight_per_op_uses_connect_timeout_for_wait_writable
    timeout = HTTP::Timeout::Global.new(global_timeout: 100, read_timeout: 0.01, write_timeout: 0.01,
                                        connect_timeout: 0.01)
    io_nil = fake(wait_readable: true, wait_writable: nil)
    socket = fake(
      to_io:            io_nil,
      closed?:          false,
      connect_nonblock: ->(*) { raise IO::EAGAINWaitWritable }
    )
    timeout.instance_variable_set(:@socket, socket)
    assert_raises(HTTP::TimeoutError) { timeout.connect_ssl }
  end
end
