# frozen_string_literal: true

require "test_helper"

describe HTTP::Timeout::Global do
  cover "HTTP::Timeout::Global*"
  let(:timeout) { HTTP::Timeout::Global.new(global_timeout: 5) }

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
      socket = fake(
        to_io:            io,
        closed?:          false,
        connect_nonblock: ->(*) { socket }
      )
      # Need a real reference for the return value
      connected = Object.new
      socket = fake(
        to_io:            io,
        closed?:          false,
        connect_nonblock: ->(*) { connected }
      )
      timeout.instance_variable_set(:@socket, socket)
      timeout.connect_ssl
    end

    context "when IO::WaitReadable is raised" do
      it "waits and retries" do
        call_count = 0
        connected = Object.new
        socket = fake(
          to_io:            io,
          closed?:          false,
          connect_nonblock: proc { |*|
            call_count += 1
            raise IO::EAGAINWaitReadable if call_count == 1

            connected
          }
        )
        timeout.instance_variable_set(:@socket, socket)
        timeout.connect_ssl
      end
    end

    context "when IO::WaitWritable is raised" do
      it "waits and retries" do
        call_count = 0
        connected = Object.new
        socket = fake(
          to_io:            io,
          closed?:          false,
          connect_nonblock: proc { |*|
            call_count += 1
            raise IO::EAGAINWaitWritable if call_count == 1

            connected
          }
        )
        timeout.instance_variable_set(:@socket, socket)
        timeout.connect_ssl
      end
    end
  end

  describe "#perform_io (via readpartial)" do
    context "when result is :wait_readable" do
      it "waits and retries" do
        call_count = 0
        socket = fake(
          to_io:         io,
          closed?:       false,
          read_nonblock: proc { |*|
            call_count += 1
            call_count == 1 ? :wait_readable : "data"
          }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal "data", timeout.readpartial(10)
      end
    end

    context "when result is :wait_writable (via write)" do
      it "waits and retries" do
        call_count = 0
        socket = fake(
          to_io:          io,
          closed?:        false,
          write_nonblock: proc { |*|
            call_count += 1
            call_count == 1 ? :wait_writable : 4
          }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal 4, timeout.write("data")
      end
    end

    context "when IO::WaitReadable is raised" do
      it "waits and retries" do
        call_count = 0
        socket = fake(
          to_io:         io,
          closed?:       false,
          read_nonblock: proc { |*|
            call_count += 1
            raise IO::EAGAINWaitReadable if call_count == 1

            "data"
          }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal "data", timeout.readpartial(10)
      end
    end

    context "when IO::WaitWritable is raised" do
      it "waits and retries" do
        call_count = 0
        socket = fake(
          to_io:          io,
          closed?:        false,
          write_nonblock: proc { |*|
            call_count += 1
            raise IO::EAGAINWaitWritable if call_count == 1

            4
          }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal 4, timeout.write("data")
      end
    end

    context "when result is nil (EOF)" do
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

    context "when EOFError is raised" do
      it "returns :eof" do
        socket = fake(
          to_io:         io,
          closed?:       false,
          read_nonblock: ->(*) { raise EOFError }
        )
        timeout.instance_variable_set(:@socket, socket)

        assert_equal :eof, timeout.readpartial(10)
      end
    end
  end
end
