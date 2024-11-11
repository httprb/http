# frozen_string_literal: true

RSpec.describe HTTP::Features::RaiseError do
  subject(:feature) { described_class.new(ignore: ignore) }

  let(:connection) { double }
  let(:status) { 200 }
  let(:ignore) { [] }

  describe "#wrap_response" do
    subject(:result) { feature.wrap_response(response) }

    let(:response) do
      HTTP::Response.new(
        version:    "1.1",
        status:     status,
        headers:    {},
        connection: connection,
        request:    HTTP::Request.new(verb: :get, uri: "https://example.com")
      )
    end

    context "when status is 200" do
      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when status is 399" do
      let(:status) { 399 }

      it "returns original request" do
        expect(result).to be response
      end
    end

    context "when status is 400" do
      let(:status) { 400 }

      it "raises" do
        expect { result }.to raise_error(HTTP::StatusError, "Unexpected status code 400")
      end
    end

    context "when status is 599" do
      let(:status) { 599 }

      it "raises" do
        expect { result }.to raise_error(HTTP::StatusError, "Unexpected status code 599")
      end
    end

    context "when error status is ignored" do
      let(:status) { 500 }
      let(:ignore) { [500] }

      it "returns original request" do
        expect(result).to be response
      end
    end
  end
end
