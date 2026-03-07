# frozen_string_literal: true

require "test_helper"

describe HTTP::Timeout::PerOperation do
  cover "HTTP::Timeout::PerOperation*"
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
      timeout.connect(socket_class, "example.com", 80, true)

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
  end
end
