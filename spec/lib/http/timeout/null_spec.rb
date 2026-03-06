# frozen_string_literal: true

RSpec.describe HTTP::Timeout::Null do
  subject(:timeout) { described_class.new }

  let(:io) { double(wait_readable: true, wait_writable: true) }
  let(:socket) { double(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
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
