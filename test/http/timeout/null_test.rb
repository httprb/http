# frozen_string_literal: true

require "test_helper"

describe HTTP::Timeout::Null do
  cover "HTTP::Timeout::Null*"
  let(:timeout) { HTTP::Timeout::Null.new }

  let(:io) { fake(wait_readable: true, wait_writable: true) }
  let(:socket) { fake(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
  end

  describe "#initialize" do
    it "stores provided options compacted" do
      t = HTTP::Timeout::Null.new(read_timeout: 5, write_timeout: 10)

      assert_equal({ read_timeout: 5, write_timeout: 10 }, t.options)
    end
  end

  describe "#start_tls" do
    context "when ssl socket does not respond to hostname= or sync_close=" do
      it "skips hostname= and sync_close=" do
        ssl_socket = fake(connect: nil)
        ssl_socket_class = fake(new: ssl_socket)
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

        timeout.start_tls("example.com", ssl_socket_class, ssl_context)
      end
    end

    context "when verify_mode is not VERIFY_PEER" do
      it "skips post_connection_check" do
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

        timeout.start_tls("example.com", ssl_socket_class, ssl_context)

        refute post_connection_check_called
      end
    end

    context "when verify_mode is VERIFY_PEER and verify_hostname is true" do
      it "calls post_connection_check" do
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

        timeout.start_tls("example.com", ssl_socket_class, ssl_context)

        assert post_connection_check_called
        assert_equal "example.com", post_connection_check_arg
      end
    end

    context "when verify_hostname is false" do
      it "skips post_connection_check" do
        post_connection_check_called = false
        ssl_socket = fake(
          connect:               nil,
          "hostname=":           ->(*) {},
          "sync_close=":         ->(*) {},
          post_connection_check: ->(*) { post_connection_check_called = true }
        )
        ssl_socket_class = fake(new: ssl_socket)

        # We need a real SSLContext but need to control verify_hostname
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ssl_context.verify_hostname = false

        timeout.start_tls("example.com", ssl_socket_class, ssl_context)

        refute post_connection_check_called
      end
    end
  end

  describe "#rescue_readable (private)" do
    it "yields the block" do
      assert_equal :ok, timeout.send(:rescue_readable, 1) { :ok }
    end

    context "when IO::WaitReadable is raised and wait succeeds" do
      it "retries" do
        call_count = 0
        result = timeout.send(:rescue_readable, 1) do
          raise IO::EAGAINWaitReadable if (call_count += 1) == 1

          :done
        end

        assert_equal :done, result
      end
    end

    context "when IO::WaitReadable is raised and wait times out" do
      it "raises TimeoutError" do
        io_with_nil_wait = fake(wait_readable: nil, wait_writable: true)
        socket_with_nil_wait = fake(to_io: io_with_nil_wait, closed?: false)
        timeout.instance_variable_set(:@socket, socket_with_nil_wait)

        err = assert_raises(HTTP::TimeoutError) do
          timeout.send(:rescue_readable, 1) { raise IO::EAGAINWaitReadable }
        end
        assert_match(/Read timed out/, err.message)
      end
    end
  end

  describe "#rescue_writable (private)" do
    it "yields the block" do
      assert_equal :ok, timeout.send(:rescue_writable, 1) { :ok }
    end

    context "when IO::WaitWritable is raised and wait succeeds" do
      it "retries" do
        call_count = 0
        result = timeout.send(:rescue_writable, 1) do
          raise IO::EAGAINWaitWritable if (call_count += 1) == 1

          :done
        end

        assert_equal :done, result
      end
    end

    context "when IO::WaitWritable is raised and wait times out" do
      it "raises TimeoutError" do
        io_with_nil_wait = fake(wait_readable: true, wait_writable: nil)
        socket_with_nil_wait = fake(to_io: io_with_nil_wait, closed?: false)
        timeout.instance_variable_set(:@socket, socket_with_nil_wait)

        err = assert_raises(HTTP::TimeoutError) do
          timeout.send(:rescue_writable, 1) { raise IO::EAGAINWaitWritable }
        end
        assert_match(/Write timed out/, err.message)
      end
    end
  end

  describe "NATIVE_CONNECT_TIMEOUT" do
    it "is true on Ruby 3.4+" do
      assert_equal RUBY_VERSION >= "3.4", HTTP::Timeout::Null::NATIVE_CONNECT_TIMEOUT
    end
  end

  describe "#open_socket (private)" do
    it "opens a socket without timeout" do
      tcp_socket = fake(closed?: false)
      socket_class = fake(open: tcp_socket)

      result = timeout.send(:open_socket, socket_class, "example.com", 80)

      assert_same tcp_socket, result
    end

    it "passes connect_timeout natively when native timeout is supported" do
      received_args = nil
      stub_open = lambda do |*args, **kwargs|
        received_args = [args, kwargs]
        fake(closed?: false)
      end

      timeout.stub(:native_timeout?, true) do
        TCPSocket.stub(:open, stub_open) do
          timeout.send(:open_socket, TCPSocket, "127.0.0.1", 1, connect_timeout: 5)
        end
      end

      assert_equal [["127.0.0.1", 1], { connect_timeout: 5 }], received_args
    end

    it "does not pass connect_timeout to non-TCPSocket classes" do
      received_args = nil
      tcp_socket = fake(closed?: false)
      socket_class = fake(open: proc { |*args|
        received_args = args
        tcp_socket
      })

      timeout.send(:open_socket, socket_class, "example.com", 80, connect_timeout: 5)

      assert_equal ["example.com", 80], received_args
    end

    it "converts IO::TimeoutError to ConnectTimeoutError" do
      socket_class = fake(open: proc { |*| raise IO::TimeoutError, "Connect timed out!" })

      err = assert_raises(HTTP::ConnectTimeoutError) do
        timeout.send(:open_socket, socket_class, "example.com", 80, connect_timeout: 5)
      end
      assert_match(/Connect timed out/, err.message)
    end
  end

  describe "#native_timeout? (private)" do
    if RUBY_VERSION >= "3.4"
      it "returns true for TCPSocket on Ruby 3.4+" do
        assert timeout.send(:native_timeout?, TCPSocket)
      end
    else
      it "returns false for TCPSocket on Ruby < 3.4" do
        refute timeout.send(:native_timeout?, TCPSocket)
      end
    end

    it "returns false for non-TCPSocket classes" do
      refute timeout.send(:native_timeout?, OpenSSL::SSL::SSLSocket)
    end

    it "returns false for non-class objects" do
      refute timeout.send(:native_timeout?, fake(open: nil))
    end
  end
end
