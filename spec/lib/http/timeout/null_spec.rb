# frozen_string_literal: true

RSpec.describe HTTP::Timeout::Null do
  subject(:timeout) { described_class.new }

  let(:io) { double(wait_readable: true, wait_writable: true) }
  let(:socket) { double(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
  end

  describe "#start_tls" do
    let(:ssl_socket_class) { double }

    context "when ssl socket does not respond to hostname= or sync_close=" do
      let(:ssl_socket) { double(connect: nil) }
      let(:ssl_context) do
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ctx
      end

      before do
        allow(ssl_socket_class).to receive(:new).and_return(ssl_socket)
      end

      it "skips hostname= and sync_close=" do
        expect { timeout.start_tls("example.com", ssl_socket_class, ssl_context) }.not_to raise_error
      end
    end

    context "when verify_mode is not VERIFY_PEER" do
      let(:ssl_socket) { double(connect: nil) }
      let(:ssl_context) do
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ctx
      end

      before do
        allow(ssl_socket_class).to receive(:new).and_return(ssl_socket)
        allow(ssl_socket).to receive(:hostname=)
        allow(ssl_socket).to receive(:sync_close=)
      end

      it "skips post_connection_check" do
        expect(ssl_socket).not_to receive(:post_connection_check)
        timeout.start_tls("example.com", ssl_socket_class, ssl_context)
      end
    end

    context "when verify_mode is VERIFY_PEER and verify_hostname is true" do
      let(:ssl_socket) { double(connect: nil) }
      let(:ssl_context) do
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.verify_hostname = true
        ctx
      end

      before do
        allow(ssl_socket_class).to receive(:new).and_return(ssl_socket)
        allow(ssl_socket).to receive(:hostname=)
        allow(ssl_socket).to receive(:sync_close=)
        allow(ssl_socket).to receive(:post_connection_check)
      end

      it "calls post_connection_check" do
        expect(ssl_socket).to receive(:post_connection_check).with("example.com")
        timeout.start_tls("example.com", ssl_socket_class, ssl_context)
      end
    end

    context "when verify_hostname is false" do
      let(:ssl_socket) { double(connect: nil) }
      let(:ssl_context) do
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx
      end

      before do
        allow(ssl_socket_class).to receive(:new).and_return(ssl_socket)
        allow(ssl_socket).to receive(:hostname=)
        allow(ssl_socket).to receive(:sync_close=)
        allow(ssl_context).to receive(:respond_to?).and_call_original
        allow(ssl_context).to receive(:respond_to?).with(:verify_hostname).and_return(true)
        allow(ssl_context).to receive(:verify_hostname).and_return(false)
      end

      it "skips post_connection_check" do
        expect(ssl_socket).not_to receive(:post_connection_check)
        timeout.start_tls("example.com", ssl_socket_class, ssl_context)
      end
    end
  end

  describe "#rescue_readable (private)" do
    it "yields the block" do
      expect(timeout.send(:rescue_readable, 1) { :ok }).to eq :ok
    end

    context "when IO::WaitReadable is raised and wait succeeds" do
      before do
        allow(io).to receive(:wait_readable).and_return(true)
        @call_count = 0
      end

      it "retries" do
        result = timeout.send(:rescue_readable, 1) do
          raise IO::EAGAINWaitReadable if (@call_count += 1) == 1

          :done
        end
        expect(result).to eq :done
      end
    end

    context "when IO::WaitReadable is raised and wait times out" do
      before { allow(io).to receive(:wait_readable).and_return(nil) }

      it "raises TimeoutError" do
        expect do
          timeout.send(:rescue_readable, 1) { raise IO::EAGAINWaitReadable }
        end.to raise_error(HTTP::TimeoutError, /Read timed out/)
      end
    end
  end

  describe "#rescue_writable (private)" do
    it "yields the block" do
      expect(timeout.send(:rescue_writable, 1) { :ok }).to eq :ok
    end

    context "when IO::WaitWritable is raised and wait succeeds" do
      before do
        allow(io).to receive(:wait_writable).and_return(true)
        @call_count = 0
      end

      it "retries" do
        result = timeout.send(:rescue_writable, 1) do
          raise IO::EAGAINWaitWritable if (@call_count += 1) == 1

          :done
        end
        expect(result).to eq :done
      end
    end

    context "when IO::WaitWritable is raised and wait times out" do
      before { allow(io).to receive(:wait_writable).and_return(nil) }

      it "raises TimeoutError" do
        expect do
          timeout.send(:rescue_writable, 1) { raise IO::EAGAINWaitWritable }
        end.to raise_error(HTTP::TimeoutError, /Write timed out/)
      end
    end
  end
end
