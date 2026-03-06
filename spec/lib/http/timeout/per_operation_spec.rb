# frozen_string_literal: true

RSpec.describe HTTP::Timeout::PerOperation do
  subject(:timeout) { described_class.new(connect_timeout: 1, read_timeout: 1, write_timeout: 1) }

  let(:io) { double(wait_readable: true, wait_writable: true) }
  let(:socket) { double(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
  end

  describe "#connect" do
    let(:socket_class) { double }
    let(:tcp_socket) { double }

    before do
      allow(socket_class).to receive(:open).and_return(tcp_socket)
    end

    it "sets TCP_NODELAY when nodelay is true" do
      expect(tcp_socket).to receive(:setsockopt).with(
        Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
      )
      timeout.connect(socket_class, "example.com", 80, true)
    end
  end

  describe "#connect_ssl" do
    before { allow(socket).to receive(:connect_nonblock).and_return(socket) }

    it "completes without error" do
      expect { timeout.connect_ssl }.not_to raise_error
    end
  end

  describe "#readpartial" do
    context "when read returns nil (EOF)" do
      before do
        allow(socket).to receive(:read_nonblock).and_return(nil)
      end

      it "returns :eof" do
        expect(timeout.readpartial(10)).to eq :eof
      end
    end
  end

  describe "#write" do
    context "when write times out" do
      before do
        allow(socket).to receive(:write_nonblock).and_return(:wait_writable)
        allow(io).to receive(:wait_writable).and_return(nil)
      end

      it "raises TimeoutError" do
        expect { timeout.write("data") }.to raise_error(HTTP::TimeoutError, /Write timed out/)
      end
    end
  end
end
