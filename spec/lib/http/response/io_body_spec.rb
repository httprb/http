RSpec.describe HTTP::Response::IoBody do
  subject(:body) { described_class.new StringIO.new("Hello, World!") }

  it "has the content" do
    expect(subject.to_s).to eq "Hello, World!"
  end

  context "when body empty" do
    subject(:body) { described_class.new StringIO.new("") }

    it "returns responds to empty? with true" do
      expect(subject).to be_empty
    end
  end

  describe "#readpartial" do
    context "with size given" do
      it "returns only that amount" do
        expect(body.readpartial(4)).to eq "Hell"
      end
    end

    context "without size given" do
      it "returns parts of the content" do
        expect(body.readpartial).to eq "Hello, World!"
      end
    end
  end

  describe "#each" do
    it "yields successive parts of the content" do
      expect { |b| body.each(&b) }.to yield_with_args "Hello, World!"
    end
  end

end
