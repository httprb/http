# frozen_string_literal: true
# coding: utf-8

RSpec.describe HTTP::Request::Writer do
  let(:io)          { StringIO.new }
  let(:body)        { "" }
  let(:headers)     { HTTP::Headers.new }
  let(:headerstart) { "GET /test HTTP/1.1" }

  subject(:writer)  { described_class.new(io, body, headers, headerstart) }

  describe "#initalize" do
    context "when body is nil" do
      let(:body) { nil }

      it "does not raise an error" do
        expect { writer }.not_to raise_error
      end
    end

    context "when body is a string" do
      let(:body) { "string body" }

      it "does not raise an error" do
        expect { writer }.not_to raise_error
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w(bees cows) }

      it "does not raise an error" do
        expect { writer }.not_to raise_error
      end
    end

    context "when body is not string, enumerable or nil" do
      let(:body) { 123 }

      it "raises an error" do
        expect { writer }.to raise_error(HTTP::RequestError)
      end
    end
  end

  describe "#stream" do
    context "when body is Enumerable" do
      let(:body)    { %w(bees cows) }
      let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }

      it "writes a chunked request from an Enumerable correctly" do
        writer.stream
        expect(io.string).to end_with "\r\n4\r\nbees\r\n4\r\ncows\r\n0\r\n\r\n"
      end

      it "writes Transfer-Encoding header only once" do
        writer.stream
        expect(io.string).to start_with "#{headerstart}\r\nTransfer-Encoding: chunked\r\n\r\n"
      end

      context "when Transfer-Encoding not set" do
        let(:headers) { HTTP::Headers.new }
        specify { expect { writer.stream }.to raise_error(HTTP::RequestError) }
      end

      context "when Transfer-Encoding is not chunked" do
        let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "gzip" }
        specify { expect { writer.stream }.to raise_error(HTTP::RequestError) }
      end
    end

    context "when body is nil" do
      let(:body) { nil }

      it "properly sets Content-Length header if needed" do
        writer.stream
        expect(io.string).to start_with "#{headerstart}\r\nContent-Length: 0\r\n\r\n"
      end

      context "when Content-Length explicitly set" do
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 12 }

        it "keeps given value" do
          writer.stream
          expect(io.string).to start_with "#{headerstart}\r\nContent-Length: 12\r\n\r\n"
        end
      end
    end

    context "when body is a unicode String" do
      let(:body) { "Привет, мир!" }

      it "properly calculates Content-Length if needed" do
        writer.stream
        expect(io.string).to start_with "#{headerstart}\r\nContent-Length: 21\r\n\r\n"
      end

      context "when Content-Length explicitly set" do
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 12 }

        it "keeps given value" do
          writer.stream
          expect(io.string).to start_with "#{headerstart}\r\nContent-Length: 12\r\n\r\n"
        end
      end
    end
  end
end
