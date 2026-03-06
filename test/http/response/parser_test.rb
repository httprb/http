# frozen_string_literal: true

require "test_helper"

describe HTTP::Response::Parser do
  let(:parser) { HTTP::Response::Parser.new }

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

  context "whole response in one part" do
    before { parser.add(raw_response) }

    it "parses headers" do
      assert_equal expected_headers, parser.headers.to_h
    end

    it "parses body" do
      assert_equal expected_body, parser.read(expected_body.size)
    end
  end

  context "response in many parts" do
    before { raw_response.chars.each { |part| parser.add(part) } }

    it "parses headers" do
      assert_equal expected_headers, parser.headers.to_h
    end

    it "parses body" do
      assert_equal expected_body, parser.read(expected_body.size)
    end
  end

  describe "#add with invalid data" do
    it "raises IOError on invalid HTTP data" do
      assert_raises(IOError) { parser.add("NOT HTTP AT ALL\r\n\r\n") }
    end
  end

  describe "#read with chunk larger than requested size" do
    let(:raw_response) do
      "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n0123456789"
    end

    before { parser.add(raw_response) }

    it "returns only the requested bytes and retains the rest" do
      chunk = parser.read(4)

      assert_equal "0123", chunk
      chunk = parser.read(6)

      assert_equal "456789", chunk
    end
  end

  context "when got 100 Continue response" do
    let(:raw_response) do
      "HTTP/1.1 100 Continue\r\n\r\n" \
        "HTTP/1.1 200 OK\r\n" \
        "Content-Length: 12\r\n\r\n" \
        "Hello World!"
    end

    context "when response is fed in one part" do
      before { parser.add(raw_response) }

      it "skips to next non-info response" do
        assert_equal 200, parser.status_code
        assert_equal({ "Content-Length" => "12" }, parser.headers)
        assert_equal "Hello World!", parser.read(12)
      end
    end

    context "when response is fed in many parts" do
      before { raw_response.chars.each { |part| parser.add(part) } }

      it "skips to next non-info response" do
        assert_equal 200, parser.status_code
        assert_equal({ "Content-Length" => "12" }, parser.headers)
        assert_equal "Hello World!", parser.read(12)
      end
    end
  end
end
