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

    context "when body is an IO" do
      let(:body) { StringIO.new("string body") }

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

    context "when body is of unrecognized type" do
      let(:body) { 123 }

      it "raises an error" do
        expect { writer }.to raise_error(HTTP::RequestError)
      end
    end
  end

  describe "#stream" do
    context "when multiple headers are set" do
      let(:body) { "content" }
      let(:headers) { HTTP::Headers.coerce "Host" => "example.org" }

      it "separates headers with carriage return and line feed" do
        writer.stream
        expect(io.string).to eq [
          "#{headerstart}\r\n",
          "Host: example.org\r\nContent-Length: 7\r\n\r\n",
          "content",
        ].join
      end
    end

    context "when body is a String" do
      let(:body) { "Привет, мир!" }

      it "writes content and sets Content-Length" do
        writer.stream
        expect(io.string).to eq [
          "#{headerstart}\r\n",
          "Content-Length: 21\r\n\r\n",
          "Привет, мир!",
        ].join
      end

      context "when Transfer-Encoding is chunked" do
        let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }

        it "writes encoded content and omits Content-Length" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Transfer-Encoding: chunked\r\n\r\n",
            "15\r\nПривет, мир!\r\n0\r\n\r\n",
          ].join
        end
      end

      context "when Content-Length explicitly set" do
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 12 }

        it "keeps Content-Length" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Content-Length: 12\r\n\r\n",
            "Привет, мир!",
          ].join
        end
      end
    end

    context "when body is Enumerable" do
      let(:body)    { %w(bees cows) }
      let(:headers) { HTTP::Headers.coerce "Content-Length" => 8 }

      it "writes content and sets Content-Length" do
        writer.stream
        expect(io.string).to eq [
          "#{headerstart}\r\n",
          "Content-Length: 8\r\n\r\n",
          "beescows",
        ].join
      end

      context "when Content-Length is not set" do
        let(:headers) { HTTP::Headers.new }

        it "raises an error" do
          expect { writer.stream }.to raise_error(HTTP::RequestError)
        end
      end

      context "when Enumerable is empty" do
        let(:body)    { %w() }
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 0 }

        it "doesn't write anything" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Content-Length: 0\r\n\r\n",
          ].join
        end
      end

      context "when Transfer-Encoding is chunked" do
        let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }

        it "writes encoded content and doesn't require Content-Length" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Transfer-Encoding: chunked\r\n\r\n",
            "4\r\nbees\r\n4\r\ncows\r\n0\r\n\r\n",
          ].join
        end
      end
    end

    context "when body is an IO" do
      let(:body) { StringIO.new("a" * 16 * 1024 + "b" * 10 * 1024) }

      it "writes content and sets Content-Length" do
        writer.stream
        expect(io.string).to eq [
          "#{headerstart}\r\n",
          "Content-Length: #{body.size}\r\n\r\n",
          body.string,
        ].join
      end

      it "raises error when IO object doesn't respond to #size" do
        body.instance_eval { undef size }
        expect { writer.stream }.to raise_error(HTTP::RequestError)
      end

      context "when Transfer-Encoding is chunked" do
        let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }

        it "writes encoded content and doesn't require Content-Length" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Transfer-Encoding: chunked\r\n\r\n",
            "4000\r\n#{"a" * 16 * 1024}\r\n2800\r\n#{"b" * 10 * 1024}\r\n0\r\n\r\n",
          ].join
        end

        it "doesn't require body to respond to #size" do
          body.instance_eval { undef size }
          writer.stream
        end
      end

      context "when Content-Length explicitly set" do
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 12 }

        it "keeps given value" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Content-Length: 12\r\n\r\n",
            body.string,
          ].join
        end

        it "doesn't require body to respond to #size" do
          body.instance_eval { undef size }
          writer.stream
        end
      end
    end

    context "when body is nil" do
      let(:body) { nil }

      it "writes empty content and sets Content-Length" do
        writer.stream
        expect(io.string).to eq [
          "#{headerstart}\r\n",
          "Content-Length: 0\r\n\r\n",
        ].join
      end

      context "when Transfer-Encoding is chunked" do
        let(:headers) { HTTP::Headers.coerce "Transfer-Encoding" => "chunked" }

        it "writes empty content and doesn't require Content-Length" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Transfer-Encoding: chunked\r\n\r\n",
            "0\r\n\r\n",
          ].join
        end
      end

      context "when Content-Length explicitly set" do
        let(:headers) { HTTP::Headers.coerce "Content-Length" => 12 }

        it "keeps given value" do
          writer.stream
          expect(io.string).to eq [
            "#{headerstart}\r\n",
            "Content-Length: 12\r\n\r\n",
          ].join
        end
      end
    end
  end
end
