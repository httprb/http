# frozen_string_literal: true

RSpec.describe HTTP::Timeout::Global do
  subject { described_class.new(:global_timeout => 1) }

  let(:socket_class) { double("SocketClass", :open => socket) }
  let(:socket) { double("Socket", :setsockopt => nil) }

  describe "#connect" do
    it "strips brackets from IPv6 addresses before sending them to the socket" do
      expect(socket_class).to receive(:open).with("2606:2800:220:1:248:1893:25c8:1946", 80)

      subject.connect(socket_class, "[2606:2800:220:1:248:1893:25c8:1946]", 80)
    end
  end
end
