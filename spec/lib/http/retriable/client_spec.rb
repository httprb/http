# frozen_string_literal: true

RSpec.describe HTTP::Retriable::Client do
  describe "#branch (private)" do
    let(:performer) { HTTP::Retriable::Performer.new({}) }
    let(:client) { described_class.new(performer, HTTP::Options.new) }

    it "returns a Retriable::Client when chaining" do
      chained = client.headers("Accept" => "text/html")
      expect(chained).to be_a described_class
    end
  end
end
