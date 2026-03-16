# frozen_string_literal: true

require "test_helper"

class HTTPTimeoutNullTest < Minitest::Test
  cover "HTTP::Timeout::Null*"

  def setup
    super
    @io = fake(wait_readable: true, wait_writable: true)
    @socket = fake(to_io: @io, closed?: false)
    @timeout = HTTP::Timeout::Null.new
    @timeout.instance_variable_set(:@socket, @socket)
  end

  # -- #initialize --

  def test_initialize_stores_provided_options_compacted
    t = HTTP::Timeout::Null.new(read_timeout: 5, write_timeout: 10)

    assert_equal({ read_timeout: 5, write_timeout: 10 }, t.options)
  end

  # -- #start_tls --

  def test_start_tls_skips_hostname_and_sync_close_when_not_responding
    ssl_socket = fake(connect: nil)
    ssl_socket_class = fake(new: ssl_socket)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @timeout.start_tls("example.com", ssl_socket_class, ssl_context)
  end

  def test_start_tls_skips_post_connection_check_when_verify_mode_not_verify_peer
    post_connection_check_called = false
    ssl_socket = fake(
      connect:               nil,
      "hostname=":           ->(*) {},
      "sync_close=":         ->(*) {},
      post_connection_check: ->(*) { post_connection_check_called = true }
    )
    ssl_socket_class = fake(new: ssl_socket)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @timeout.start_tls("example.com", ssl_socket_class, ssl_context)

    refute post_connection_check_called
  end

  def test_start_tls_calls_post_connection_check_when_verify_peer_and_verify_hostname
    post_connection_check_called = false
    post_connection_check_arg = nil
    ssl_socket = fake(
      connect:               nil,
      "hostname=":           ->(*) {},
      "sync_close=":         ->(*) {},
      post_connection_check: lambda { |host|
        post_connection_check_called = true
        post_connection_check_arg = host
      }
    )
    ssl_socket_class = fake(new: ssl_socket)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    ssl_context.verify_hostname = true
    @timeout.start_tls("example.com", ssl_socket_class, ssl_context)

    assert post_connection_check_called
    assert_equal "example.com", post_connection_check_arg
  end

  def test_start_tls_skips_post_connection_check_when_verify_hostname_false
    post_connection_check_called = false
    ssl_socket = fake(
      connect:               nil,
      "hostname=":           ->(*) {},
      "sync_close=":         ->(*) {},
      post_connection_check: ->(*) { post_connection_check_called = true }
    )
    ssl_socket_class = fake(new: ssl_socket)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    ssl_context.verify_hostname = false
    @timeout.start_tls("example.com", ssl_socket_class, ssl_context)

    refute post_connection_check_called
  end

  # -- #rescue_readable (private) --

  def test_rescue_readable_yields_the_block
    assert_equal :ok, @timeout.send(:rescue_readable, 1) { :ok }
  end

  def test_rescue_readable_when_wait_readable_raised_and_wait_succeeds_retries
    call_count = 0
    result = @timeout.send(:rescue_readable, 1) do
      raise IO::EAGAINWaitReadable if (call_count += 1) == 1

      :done
    end

    assert_equal :done, result
  end

  def test_rescue_readable_when_wait_readable_raised_and_wait_times_out_raises_timeout_error
    io_with_nil_wait = fake(wait_readable: nil, wait_writable: true)
    socket_with_nil_wait = fake(to_io: io_with_nil_wait, closed?: false)
    @timeout.instance_variable_set(:@socket, socket_with_nil_wait)

    err = assert_raises(HTTP::TimeoutError) do
      @timeout.send(:rescue_readable, 1) { raise IO::EAGAINWaitReadable }
    end
    assert_match(/Read timed out/, err.message)
  end

  # -- #rescue_writable (private) --

  def test_rescue_writable_yields_the_block
    assert_equal :ok, @timeout.send(:rescue_writable, 1) { :ok }
  end

  def test_rescue_writable_when_wait_writable_raised_and_wait_succeeds_retries
    call_count = 0
    result = @timeout.send(:rescue_writable, 1) do
      raise IO::EAGAINWaitWritable if (call_count += 1) == 1

      :done
    end

    assert_equal :done, result
  end

  def test_rescue_writable_when_wait_writable_raised_and_wait_times_out_raises_timeout_error
    io_with_nil_wait = fake(wait_readable: true, wait_writable: nil)
    socket_with_nil_wait = fake(to_io: io_with_nil_wait, closed?: false)
    @timeout.instance_variable_set(:@socket, socket_with_nil_wait)

    err = assert_raises(HTTP::TimeoutError) do
      @timeout.send(:rescue_writable, 1) { raise IO::EAGAINWaitWritable }
    end
    assert_match(/Write timed out/, err.message)
  end

  # -- NATIVE_CONNECT_TIMEOUT --

  def test_native_connect_timeout_is_true_on_ruby_3_4_plus
    assert_equal RUBY_VERSION >= "3.4", HTTP::Timeout::Null::NATIVE_CONNECT_TIMEOUT
  end

  # -- #open_socket (private) --

  def test_open_socket_opens_a_socket_without_timeout
    tcp_socket = fake(closed?: false)
    socket_class = fake(open: tcp_socket)
    result = @timeout.send(:open_socket, socket_class, "example.com", 80)

    assert_same tcp_socket, result
  end

  def test_open_socket_passes_connect_timeout_natively_when_supported
    received_args = nil
    stub_open = lambda do |*args, **kwargs|
      received_args = [args, kwargs]
      fake(closed?: false)
    end

    @timeout.stub(:native_timeout?, true) do
      TCPSocket.stub(:open, stub_open) do
        @timeout.send(:open_socket, TCPSocket, "127.0.0.1", 1, connect_timeout: 5)
      end
    end

    assert_equal [["127.0.0.1", 1], { connect_timeout: 5 }], received_args
  end

  def test_open_socket_does_not_pass_connect_timeout_to_non_tcp_socket_classes
    received_args = nil
    tcp_socket = fake(closed?: false)
    socket_class = fake(open: proc { |*args|
      received_args = args
      tcp_socket
    })

    @timeout.send(:open_socket, socket_class, "example.com", 80, connect_timeout: 5)

    assert_equal ["example.com", 80], received_args
  end

  def test_open_socket_converts_io_timeout_error_to_connect_timeout_error
    socket_class = fake(open: proc { |*| raise IO::TimeoutError, "Connect timed out!" })

    err = assert_raises(HTTP::ConnectTimeoutError) do
      @timeout.send(:open_socket, socket_class, "example.com", 80, connect_timeout: 5)
    end
    assert_match(/Connect timed out/, err.message)
  end

  # -- #native_timeout? (private) --

  if RUBY_VERSION >= "3.4"
    def test_native_timeout_returns_true_for_tcp_socket_on_ruby_3_4_plus
      assert @timeout.send(:native_timeout?, TCPSocket)
    end
  else
    def test_native_timeout_returns_false_for_tcp_socket_on_ruby_below_3_4
      refute @timeout.send(:native_timeout?, TCPSocket)
    end
  end

  def test_native_timeout_returns_false_for_non_tcp_socket_classes
    refute @timeout.send(:native_timeout?, OpenSSL::SSL::SSLSocket)
  end

  def test_native_timeout_returns_false_for_non_class_objects
    refute @timeout.send(:native_timeout?, fake(open: nil))
  end
end
