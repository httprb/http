# frozen_string_literal: true

RSpec.describe HTTP::Response::Parser do
  subject(:parser) { described_class.new }

  let(:raw_response) do
    "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: application/json\r\nMyHeader: val\r\nEmptyHeader: \r\n\r\n{}"
  end
  let(:expected_headers) do
    {
      "Content-Length" => "2",
      "Content-Type"   => "application/json",
      "MyHeader"       => "val",
      "EmptyHeader"    => ""
    }
  end
  let(:expected_body) { "{}" }

  before do
    parts.each { |part| subject.add(part) }
  end

  context "whole response in one part" do
    let(:parts) { [raw_response] }

    it "parses headers" do
      expect(subject.headers.to_h).to eq(expected_headers)
    end

    it "parses body" do
      expect(subject.read(expected_body.size)).to eq(expected_body)
    end
  end

  context "response in many parts" do
    let(:parts) { raw_response.chars }

    it "parses headers" do
      expect(subject.headers.to_h).to eq(expected_headers)
    end

    it "parses body" do
      expect(subject.read(expected_body.size)).to eq(expected_body)
    end
  end

  describe "#add with invalid data" do
    let(:parts) { [] }

    it "raises IOError on invalid HTTP data" do
      expect { subject.add("NOT HTTP AT ALL\r\n\r\n") }.to raise_error(IOError)
    end
  end

  describe "#read with chunk larger than requested size" do
    let(:raw_response) do
      "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n0123456789"
    end
    let(:parts) { [raw_response] }

    it "returns only the requested bytes and retains the rest" do
      chunk = subject.read(4)
      expect(chunk).to eq "0123"
      chunk = subject.read(6)
      expect(chunk).to eq "456789"
    end
  end

  context "when got 100 Continue response" do
    let :raw_response do
      "HTTP/1.1 100 Continue\r\n\r\n" \
        "HTTP/1.1 200 OK\r\n" \
        "Content-Length: 12\r\n\r\n" \
        "Hello World!"
    end

    context "when response is feeded in one part" do
      let(:parts) { [raw_response] }

      it "skips to next non-info response" do
        expect(subject.status_code).to eq(200)
        expect(subject.headers).to eq("Content-Length" => "12")
        expect(subject.read(12)).to eq("Hello World!")
      end
    end

    context "when response is feeded in many parts" do
      let(:parts) { raw_response.chars }

      it "skips to next non-info response" do
        expect(subject.status_code).to eq(200)
        expect(subject.headers).to eq("Content-Length" => "12")
        expect(subject.read(12)).to eq("Hello World!")
      end
    end
  end
end
