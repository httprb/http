RSpec.describe HTTP::Response::Body do
  let(:client)   { double(:sequence_id => 0) }
  let(:chunks)   { ["Hello, ", "World!"] }

  before         { allow(client).to receive(:readpartial) { chunks.shift } }

  subject(:body) { described_class.new client }

  it "streams bodies from responses" do
    expect(subject.to_s).to eq "Hello, World!"
  end

  context "when body empty" do
    let(:chunks) { [""] }

    it "returns responds to empty? with true" do
      expect(subject).to be_empty
    end
  end

  describe "#readpartial" do
    context "with size given" do
      it "passes value to underlying client" do
        expect(client).to receive(:readpartial).with(42)
        body.readpartial 42
      end
    end

    context "without size given" do
      it "does not blows up" do
        expect { body.readpartial }.to_not raise_error
      end

      it "calls underlying client readpartial without specific size" do
        expect(client).to receive(:readpartial).with no_args
        body.readpartial
      end
    end
  end
end
