# frozen_string_literal: true

require "test_helper"

describe HTTP::Timeout::PerOperation do
  cover "HTTP::Timeout::PerOperation*"
  describe ".extract_global_timeout!" do
    it "extracts short global key" do
      opts = { global: 60, read: 5 }

      assert_equal 60, HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
      assert_equal({ read: 5 }, opts)
    end

    it "extracts long global_timeout key" do
      opts = { global_timeout: 60, read: 5 }

      assert_equal 60, HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
      assert_equal({ read: 5 }, opts)
    end

    it "returns nil when no global key present" do
      opts = { read: 5 }

      assert_nil HTTP::Timeout::PerOperation.send(:extract_global_timeout!, opts)
      assert_equal({ read: 5 }, opts)
    end

    it "raises when both global and global_timeout given" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.send(:extract_global_timeout!, global: 60, global_timeout: 60)
      end
    end

    it "raises for non-numeric global value" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.send(:extract_global_timeout!, global: "60")
      end
    end
  end

  describe ".normalize_options" do
    it "normalizes short read key to long form" do
      assert_equal({ read_timeout: 5 }, HTTP::Timeout::PerOperation.normalize_options(read: 5))
    end

    it "normalizes short write key to long form" do
      assert_equal({ write_timeout: 3 }, HTTP::Timeout::PerOperation.normalize_options(write: 3))
    end

    it "normalizes short connect key to long form" do
      assert_equal({ connect_timeout: 1 }, HTTP::Timeout::PerOperation.normalize_options(connect: 1))
    end

    it "passes through long form keys" do
      assert_equal({ read_timeout: 5 }, HTTP::Timeout::PerOperation.normalize_options(read_timeout: 5))
    end

    it "normalizes all keys together" do
      result = HTTP::Timeout::PerOperation.normalize_options(read: 1, write: 2, connect: 3)

      assert_equal({ read_timeout: 1, write_timeout: 2, connect_timeout: 3 }, result)
    end

    it "accepts float values" do
      assert_equal({ read_timeout: 1.5 }, HTTP::Timeout::PerOperation.normalize_options(read: 1.5))
    end

    it "handles frozen hashes" do
      result = HTTP::Timeout::PerOperation.normalize_options({ read: 5 }.freeze)

      assert_equal({ read_timeout: 5 }, result)
    end

    it "raises when both short and long form of same key given" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.normalize_options(read: 1, read_timeout: 2)
      end
    end

    it "raises for non-numeric values" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.normalize_options(read: "5")
      end
    end

    it "raises for unknown keys" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.normalize_options(timeout: 5)
      end
    end

    it "raises for empty hash" do
      assert_raises(ArgumentError) do
        HTTP::Timeout::PerOperation.normalize_options({})
      end
    end
  end

  let(:timeout) { HTTP::Timeout::PerOperation.new(connect_timeout: 1, read_timeout: 1, write_timeout: 1) }

  let(:io) { fake(wait_readable: true, wait_writable: true) }
  let(:socket) { fake(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
  end

  describe "#connect" do
    it "sets TCP_NODELAY when nodelay is true" do
      setsockopt_args = nil
      tcp_socket = fake(
        setsockopt: ->(*args) { setsockopt_args = args }
      )

      socket_class = fake(open: tcp_socket)
      timeout.connect(socket_class, "example.com", 80, nodelay: true)

      assert_equal [Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1], setsockopt_args
    end
  end

  describe "#connect_ssl" do
    it "completes without error" do
      connected = Object.new
      socket = fake(
        to_io:            io,
        closed?:          false,
        connect_nonblock: ->(*) { connected }
      )
      timeout.instance_variable_set(:@socket, socket)
      timeout.connect_ssl
    end
  end

  describe "#readpartial" do
    context "when read returns nil (EOF)" do
      it "returns :eof" do
        socket = fake(
          to_io:         io,
          closed?:       false,
          read_nonblock: nil
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal :eof, timeout.readpartial(10)
      end
    end

    context "when read returns :wait_writable then data (SSL renegotiation)" do
      it "waits for writable then retries" do
        call_count = 0
        socket = fake(
          to_io:         io,
          closed?:       false,
          read_nonblock: ->(*) { (call_count += 1) == 1 ? :wait_writable : "data" }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal "data", timeout.readpartial(10)
      end
    end

    context "when read returns :wait_writable and times out" do
      it "raises TimeoutError" do
        io_with_nil_wait = fake(wait_readable: nil, wait_writable: nil)
        socket = fake(
          to_io:         io_with_nil_wait,
          closed?:       false,
          read_nonblock: :wait_writable
        )
        timeout.instance_variable_set(:@socket, socket)

        err = assert_raises(HTTP::TimeoutError) do
          timeout.readpartial(10)
        end
        assert_match(/Read timed out/, err.message)
      end
    end
  end

  describe "#write" do
    context "when write times out" do
      it "raises TimeoutError" do
        io_with_nil_wait = fake(wait_readable: true, wait_writable: nil)
        socket = fake(
          to_io:          io_with_nil_wait,
          closed?:        false,
          write_nonblock: :wait_writable
        )
        timeout.instance_variable_set(:@socket, socket)

        err = assert_raises(HTTP::TimeoutError) do
          timeout.write("data")
        end
        assert_match(/Write timed out/, err.message)
      end
    end

    context "when write returns :wait_readable then completes (SSL renegotiation)" do
      it "waits for readable then retries" do
        call_count = 0
        socket = fake(
          to_io:          io,
          closed?:        false,
          write_nonblock: ->(*) { (call_count += 1) == 1 ? :wait_readable : 4 }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal 4, timeout.write("data")
      end
    end

    context "when write returns :wait_readable and times out" do
      it "raises TimeoutError" do
        io_with_nil_wait = fake(wait_readable: nil, wait_writable: nil)
        socket = fake(
          to_io:          io_with_nil_wait,
          closed?:        false,
          write_nonblock: :wait_readable
        )
        timeout.instance_variable_set(:@socket, socket)

        err = assert_raises(HTTP::TimeoutError) do
          timeout.write("data")
        end
        assert_match(/Write timed out/, err.message)
      end
    end
  end
end
