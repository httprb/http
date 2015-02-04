RSpec.describe HTTP::Cache::CacheControl do
  describe ".new" do
    it "accepts a request" do
      expect { described_class.new request }.not_to raise_error
    end

    it "accepts a request" do
      expect { described_class.new response }.not_to raise_error
    end

    it "it rejects any object that does not respond to #headers" do
      expect { described_class.new double }.to raise_error
    end
  end

  subject { described_class.new response }

  context "cache-control: private" do
    let(:cache_control) { "private" }

    it "know it is private" do
      expect(subject.private?).to be_truthy
    end
  end

  context "cache-control: public" do
    let(:cache_control) { "public" }

    it "know it is public" do
      expect(subject.public?).to be_truthy
    end
  end

  context "cache-control: no-cache" do
    let(:cache_control) { "no-cache" }

    it "know it is no-cache" do
      expect(subject.no_cache?).to be_truthy
    end
  end

  context "cache-control: no-store" do
    let(:cache_control) { "no-store" }

    it "know it is no-store" do
      expect(subject.no_store?).to be_truthy
    end
  end

  context "cache-control: max-age=100" do
    let(:cache_control) { "max-age=100" }

    it "knows max age" do
      expect(subject.max_age).to eq 100
    end
  end

  context "expires: {100 seconds from now}" do
    let(:headers) { {"Expires" => (Time.now + 100).httpdate} }

    it "knows max age" do
      expect(subject.max_age).to be_within(1).of(100)
    end
  end

  context "expires: {100 seconds before now}" do
    let(:headers) { {"Expires" => (Time.now - 100).httpdate} }

    it "knows max age" do
      expect(subject.max_age).to eq 0
    end
  end

  context "expires: -1" do
    let(:headers) { {"Expires" => "-1"} }

    it "knows max age" do
      expect(subject.max_age).to eq 0
    end
  end

  context "vary: *" do
    let(:headers) { {"Vary" => "*"} }

    it "knows it is vary *" do
      expect(subject.vary_star?).to be_truthy
    end
  end

  context "no headers" do
    let(:headers) { {} }

    it "knows max age" do
      expect(subject.max_age).to eq Float::INFINITY
    end

    it "know it is private" do
      expect(subject.private?).to be_falsy
    end

    it "know it is public" do
      expect(subject.public?).to be_falsy
    end

    it "know it is no-cache" do
      expect(subject.no_cache?).to be_falsy
    end

    it "know it is no-store" do
      expect(subject.no_store?).to be_falsy
    end

    it "knows it is not vary *" do
      expect(subject.vary_star?).to be_falsy
    end
  end

  # Background
  let(:cache_control) { "private" }
  let(:headers) { {"Cache-Control" => cache_control} }
  let(:request) { HTTP::Request.new(:get, "http://example.com/") }

  let(:response) { HTTP::Response.new(200, "http/1.1", headers, "") }
end
