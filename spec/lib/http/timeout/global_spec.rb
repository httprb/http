# frozen_string_literal: true

RSpec.describe HTTP::Timeout::Global do
  subject(:timeout) { described_class.new(global_timeout: 5) }

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

    context "when IO::WaitReadable is raised" do
      before do
        allow(io).to receive(:wait_readable).and_return(true)
        call_count = 0
        allow(socket).to receive(:connect_nonblock) do
          call_count += 1
          raise IO::EAGAINWaitReadable if call_count == 1

          socket
        end
      end

      it "waits and retries" do
        expect { timeout.connect_ssl }.not_to raise_error
      end
    end

    context "when IO::WaitWritable is raised" do
      before do
        allow(io).to receive(:wait_writable).and_return(true)
        call_count = 0
        allow(socket).to receive(:connect_nonblock) do
          call_count += 1
          raise IO::EAGAINWaitWritable if call_count == 1

          socket
        end
      end

      it "waits and retries" do
        expect { timeout.connect_ssl }.not_to raise_error
      end
    end
  end

  describe "#perform_io (via readpartial)" do
    context "when result is :wait_readable" do
      before do
        allow(io).to receive(:wait_readable).and_return(true)
        call_count = 0
        allow(socket).to receive(:read_nonblock) do
          call_count += 1
          call_count == 1 ? :wait_readable : "data"
        end
      end

      it "waits and retries" do
        expect(timeout.readpartial(10)).to eq "data"
      end
    end

    context "when result is :wait_writable (via write)" do
      before do
        allow(io).to receive(:wait_writable).and_return(true)
        call_count = 0
        allow(socket).to receive(:write_nonblock) do
          call_count += 1
          call_count == 1 ? :wait_writable : 4
        end
      end

      it "waits and retries" do
        expect(timeout.write("data")).to eq 4
      end
    end

    context "when IO::WaitReadable is raised" do
      before do
        allow(io).to receive(:wait_readable).and_return(true)
        call_count = 0
        allow(socket).to receive(:read_nonblock) do
          call_count += 1
          raise IO::EAGAINWaitReadable if call_count == 1

          "data"
        end
      end

      it "waits and retries" do
        expect(timeout.readpartial(10)).to eq "data"
      end
    end

    context "when IO::WaitWritable is raised" do
      before do
        allow(io).to receive(:wait_writable).and_return(true)
        call_count = 0
        allow(socket).to receive(:write_nonblock) do
          call_count += 1
          raise IO::EAGAINWaitWritable if call_count == 1

          4
        end
      end

      it "waits and retries" do
        expect(timeout.write("data")).to eq 4
      end
    end

    context "when result is nil (EOF)" do
      before { allow(socket).to receive(:read_nonblock).and_return(nil) }

      it "returns :eof" do
        expect(timeout.readpartial(10)).to eq :eof
      end
    end

    context "when EOFError is raised" do
      before { allow(socket).to receive(:read_nonblock).and_raise(EOFError) }

      it "returns :eof" do
        expect(timeout.readpartial(10)).to eq :eof
      end
    end
  end
end
