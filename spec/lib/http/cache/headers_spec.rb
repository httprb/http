RSpec.describe HTTP::Cache::Headers do
  subject(:cache_headers) { described_class.new headers }

  describe ".new" do
    it "accepts instance of HTTP::Headers" do
      expect { described_class.new HTTP::Headers.new }.not_to raise_error
    end

    it "it rejects any object that does not respond to #headers" do
      expect { described_class.new double }.to raise_error HTTP::Error
    end
  end

  context "with <Cache-Control: private>" do
    let(:headers) { {"Cache-Control" => "private"} }
    it { is_expected.to be_private }
  end

  context "with <Cache-Control: public>" do
    let(:headers) { {"Cache-Control" => "public"} }
    it { is_expected.to be_public }
  end

  context "with <Cache-Control: no-cache>" do
    let(:headers) { {"Cache-Control" => "no-cache"} }
    it { is_expected.to be_no_cache }
  end

  context "with <Cache-Control: no-store>" do
    let(:headers) { {"Cache-Control" => "no-store"} }
    it { is_expected.to be_no_store }
  end

  describe "#max_age" do
    subject { cache_headers.max_age }

    context "with <Cache-Control: max-age=100>" do
      let(:headers) { {"Cache-Control" => "max-age=100"} }
      it { is_expected.to eq 100 }
    end

    context "with <Expires: {100 seconds from now}>" do
      let(:headers) { {"Expires" => (Time.now + 100).httpdate} }
      it { is_expected.to be_within(1).of(100) }
    end

    context "with <Expires: {100 seconds before now}>" do
      let(:headers) { {"Expires" => (Time.now - 100).httpdate} }
      it { is_expected.to eq 0 }
    end

    context "with <Expires: -1>" do
      let(:headers) { {"Expires" => "-1"} }
      it { is_expected.to eq 0 }
    end
  end

  context "with <Vary: *>" do
    let(:headers) { {"Vary" => "*"} }
    it { is_expected.to be_vary_star }
  end

  context "with no cache related headers" do
    let(:headers) { {} }

    it { is_expected.not_to be_private }
    it { is_expected.not_to be_public }
    it { is_expected.not_to be_no_cache }
    it { is_expected.not_to be_no_store }
    it { is_expected.not_to be_vary_star }

    describe "#max_age" do
      subject { cache_headers.max_age }
      it { is_expected.to eq Float::INFINITY }
    end
  end
end
