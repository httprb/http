# frozen_string_literal: true

require "test_helper"

class HTTPTimeoutPerOperationTest < Minitest::Test
  cover "HTTP::Timeout::PerOperation*"

  # -- instance tests --

  def setup
    super
    @io = fake(wait_readable: true, wait_writable: true)
    @socket = fake(to_io: @io, closed?: false)
    @timeout = HTTP::Timeout::PerOperation.new(connect_timeout: 1, read_timeout: 1, write_timeout: 1)
    @timeout.instance_variable_set(:@socket, @socket)
  end
  # -- .extract_global_timeout! --

  def test_extract_global_timeout_extracts_short_global_key
    opts = { global: 60, read: 5 }

    assert_equal 60, HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
    assert_equal({ read: 5 }, opts)
  end

  def test_extract_global_timeout_extracts_long_global_timeout_key
    opts = { global_timeout: 60, read: 5 }

    assert_equal 60, HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
    assert_equal({ read: 5 }, opts)
  end

  def test_extract_global_timeout_returns_nil_when_no_global_key_present
    opts = { read: 5 }

    assert_nil HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
    assert_equal({ read: 5 }, opts)
  end

  def test_extract_global_timeout_raises_when_both_global_and_global_timeout_given
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.send(:extract_global_timeout!, global: 60, global_timeout: 60)
    end
  end

  def test_extract_global_timeout_raises_for_non_numeric_global_value
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.send(:extract_global_timeout!, global: "60")
    end
  end

  # -- .normalize_options --

  def test_normalize_options_normalizes_short_read_key
    assert_equal({ read_timeout: 5 }, HTTP::Timeout::PerOperation.normalize_options(read: 5))
  end

  def test_normalize_options_normalizes_short_write_key
    assert_equal({ write_timeout: 3 }, HTTP::Timeout::PerOperation.normalize_options(write: 3))
  end

  def test_normalize_options_normalizes_short_connect_key
    assert_equal({ connect_timeout: 1 }, HTTP::Timeout::PerOperation.normalize_options(connect: 1))
  end

  def test_normalize_options_passes_through_long_form_keys
    assert_equal({ read_timeout: 5 }, HTTP::Timeout::PerOperation.normalize_options(read_timeout: 5))
  end

  def test_normalize_options_normalizes_all_keys_together
    result = HTTP::Timeout::PerOperation.normalize_options(read: 1, write: 2, connect: 3)

    assert_equal({ read_timeout: 1, write_timeout: 2, connect_timeout: 3 }, result)
  end

  def test_normalize_options_accepts_float_values
    assert_equal({ read_timeout: 1.5 }, HTTP::Timeout::PerOperation.normalize_options(read: 1.5))
  end

  def test_normalize_options_handles_frozen_hashes
    result = HTTP::Timeout::PerOperation.normalize_options({ read: 5 }.freeze)

    assert_equal({ read_timeout: 5 }, result)
  end

  def test_normalize_options_raises_when_both_short_and_long_form_given
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.normalize_options(read: 1, read_timeout: 2)
    end
  end

  def test_normalize_options_raises_for_non_numeric_values
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.normalize_options(read: "5")
    end
  end

  def test_normalize_options_raises_for_unknown_keys
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.normalize_options(timeout: 5)
    end
  end

  def test_normalize_options_raises_for_empty_hash
    assert_raises(ArgumentError) do
      HTTP::Timeout::PerOperation.normalize_options({})
    end
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

  # -- #readpartial --

  def test_readpartial_when_read_returns_nil_returns_eof
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: nil
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal :eof, @timeout.readpartial(10)
  end

  def test_readpartial_when_wait_writable_then_data_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:         @io,
      closed?:       false,
      read_nonblock: ->(*) { (call_count += 1) == 1 ? :wait_writable : "data" }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal "data", @timeout.readpartial(10)
  end

  def test_readpartial_when_wait_writable_and_times_out_raises_timeout_error
    io_with_nil_wait = fake(wait_readable: nil, wait_writable: nil)
    socket = fake(
      to_io:         io_with_nil_wait,
      closed?:       false,
      read_nonblock: :wait_writable
    )
    @timeout.instance_variable_set(:@socket, socket)

    err = assert_raises(HTTP::TimeoutError) do
      @timeout.readpartial(10)
    end
    assert_match(/Read timed out/, err.message)
  end

  # -- #write --

  def test_write_when_times_out_raises_timeout_error
    io_with_nil_wait = fake(wait_readable: true, wait_writable: nil)
    socket = fake(
      to_io:          io_with_nil_wait,
      closed?:        false,
      write_nonblock: :wait_writable
    )
    @timeout.instance_variable_set(:@socket, socket)

    err = assert_raises(HTTP::TimeoutError) do
      @timeout.write("data")
    end
    assert_match(/Write timed out/, err.message)
  end

  def test_write_when_wait_readable_then_completes_waits_and_retries
    call_count = 0
    socket = fake(
      to_io:          @io,
      closed?:        false,
      write_nonblock: ->(*) { (call_count += 1) == 1 ? :wait_readable : 4 }
    )
    @timeout.instance_variable_set(:@socket, socket)

    assert_equal 4, @timeout.write("data")
  end

  def test_write_when_wait_readable_and_times_out_raises_timeout_error
    io_with_nil_wait = fake(wait_readable: nil, wait_writable: nil)
    socket = fake(
      to_io:          io_with_nil_wait,
      closed?:        false,
      write_nonblock: :wait_readable
    )
    @timeout.instance_variable_set(:@socket, socket)

    err = assert_raises(HTTP::TimeoutError) do
      @timeout.write("data")
    end
    assert_match(/Write timed out/, err.message)
  end
end
