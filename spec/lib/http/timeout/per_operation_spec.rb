# frozen_string_literal: true

RSpec.describe HTTP::Timeout::PerOperation do
  subject(:timeout) { described_class.new(connect_timeout: 1, read_timeout: 1, write_timeout: 1) }

  let(:io) { double(wait_readable: true, wait_writable: true) }
  let(:socket) { double(to_io: io, closed?: false) }

  before do
    timeout.instance_variable_set(:@socket, socket)
  end

  describe "#connect_ssl" do
    before { allow(socket).to receive(:connect_nonblock).and_return(socket) }

    it "completes without error" do
      expect { timeout.connect_ssl }.not_to raise_error
    end
  end
end
