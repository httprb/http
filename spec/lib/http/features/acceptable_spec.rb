# frozen_string_literal: true

RSpec.describe HTTP::Features::Acceptable do
  subject(:feature) { described_class.new }

  let(:connection) { double }
  let(:headers)    { {} }

  describe "#wrap_response" do
    subject(:result) { feature.wrap_response(response) }

    let(:request) do
      HTTP::Request.new(
        verb:    :get,
        uri:     "https://example.com/",
        headers: headers
      )
    end
    let(:response) do
      HTTP::Response.new(
        version:    "1.1",
        status:     200,
        headers:    { "content-type": "text/html; charset=utf-8" },
        connection: connection,
        request:    request
      )
    end

    context "when there is no Accept header" do
      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when MIME type matches single range" do
      let(:headers) { { accept: "text/html" } }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when MIME type matches range with parameter" do
      let(:headers) { { accept: "text/html; q=1" } }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when MIME type matches one of multiple ranges" do
      let(:headers) { { accept: "text/plain, text/html, image/gif" } }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when type matches and subtype does not" do
      let(:headers) { { accept: "text/plain" } }

      it "returns synthetic 406 status" do
        expect(result.code).to be 406
      end

      it "returns original version" do
        expect(result.version).to be response.version
      end

      it "returns original headers" do
        expect(result.headers).to eq response.headers
      end

      it "returns original connection" do
        expect(result.connection).to be response.connection
      end

      it "returns original request" do
        expect(result.request).to be request
      end
    end

    context "when both type and subtype do not match" do
      let(:headers) { { accept: "image/gif" } }

      it "returns original request" do
        expect(result.code).to be 406
      end
    end

    context "when range is */*" do
      let(:headers) { { accept: "*/*" } }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when type matches and subtype is wildcard" do
      let(:headers) { { accept: "text/*" } }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when type does not match and subtype is wildcard" do
      let(:headers) { { accept: "image/*" } }

      it "returns original request" do
        expect(result.code).to be 406
      end
    end
  end
end
