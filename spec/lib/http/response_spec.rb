RSpec.describe HTTP::Response do
  let(:body)          { "Hello world!" }
  subject(:response)  { HTTP::Response.new 200, "1.1", {}, body }

  it "includes HTTP::Headers::Mixin" do
    expect(described_class).to include HTTP::Headers::Mixin
  end

  describe "to_a" do
    let(:body)         { "Hello world" }
    let(:content_type) { "text/plain" }
    subject { HTTP::Response.new(200, "1.1", {"Content-Type" => content_type}, body) }

    it "returns a Rack-like array" do
      expect(subject.to_a).to eq([200, {"Content-Type" => content_type}, body])
    end
  end

  describe "mime_type" do
    subject { HTTP::Response.new(200, "1.1", headers, "").mime_type }

    context "without Content-Type header" do
      let(:headers) { {} }
      it { is_expected.to be_nil }
    end

    context "with Content-Type: text/html" do
      let(:headers) { {"Content-Type" => "text/html"} }
      it { is_expected.to eq "text/html" }
    end

    context "with Content-Type: text/html; charset=utf-8" do
      let(:headers) { {"Content-Type" => "text/html; charset=utf-8"} }
      it { is_expected.to eq "text/html" }
    end
  end

  describe "charset" do
    subject { HTTP::Response.new(200, "1.1", headers, "").charset }

    context "without Content-Type header" do
      let(:headers) { {} }
      it { is_expected.to be_nil }
    end

    context "with Content-Type: text/html" do
      let(:headers) { {"Content-Type" => "text/html"} }
      it { is_expected.to be_nil }
    end

    context "with Content-Type: text/html; charset=utf-8" do
      let(:headers) { {"Content-Type" => "text/html; charset=utf-8"} }
      it { is_expected.to eq "utf-8" }
    end
  end

  describe "#parse" do
    let(:headers)   { {"Content-Type" => content_type} }
    let(:body)      { '{"foo":"bar"}' }
    let(:response)  { HTTP::Response.new 200, "1.1", headers, body }

    context "with known content type" do
      let(:content_type) { "application/json" }
      it "returns parsed body" do
        expect(response.parse).to eq "foo" => "bar"
      end
    end

    context "with unknown content type" do
      let(:content_type) { "application/deadbeef" }
      it "raises HTTP::Error" do
        expect { response.parse }.to raise_error HTTP::Error
      end
    end

    context "with explicitly given mime type" do
      let(:content_type) { "application/deadbeef" }
      it "ignores mime_type of response" do
        expect(response.parse "application/json").to eq "foo" => "bar"
      end

      it "supports MIME type aliases" do
        expect(response.parse :json).to eq "foo" => "bar"
      end
    end
  end

  describe "#flush" do
    let(:body)      { double :to_s => "" }
    let(:response)  { HTTP::Response.new 200, "1.1", {}, body }

    it "returns response self-reference" do
      expect(response.flush).to be response
    end

    it "flushes body" do
      expect(body).to receive :to_s
      response.flush
    end
  end

  describe "#inspect" do
    it "returns human0friendly response representation" do
      headers   = {:content_type => "text/plain"}
      body      = double :to_s => "foobar"
      response  = HTTP::Response.new(200, "1.1", headers, body)

      expect(response.inspect)
        .to eq '#<HTTP::Response/1.1 200 OK {"Content-Type"=>"text/plain"}>'
    end
  end

  describe "#cached" do
    subject { response.cached }
    it { is_expected.to be_a HTTP::Response::Cached }
  end
end
