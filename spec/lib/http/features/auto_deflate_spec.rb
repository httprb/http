# frozen_string_literal: true
RSpec.describe HTTP::Features::AutoDeflate do
  subject { HTTP::Features::AutoDeflate.new }

  it "raises error for wrong type" do
    expect { HTTP::Features::AutoDeflate.new(:method => :wrong) }.
      to raise_error(HTTP::Error) { |error|
        expect(error.message).to eq("Only gzip and deflate methods are supported")
      }
  end

  it "accepts gzip method" do
    expect(HTTP::Features::AutoDeflate.new(:method => :gzip).method).to eq "gzip"
  end

  it "accepts deflate method" do
    expect(HTTP::Features::AutoDeflate.new(:method => :deflate).method).to eq "deflate"
  end

  it "accepts string as method" do
    expect(HTTP::Features::AutoDeflate.new(:method => "gzip").method).to eq "gzip"
  end

  it "uses gzip by default" do
    expect(subject.method).to eq("gzip")
  end

  describe "#deflate" do
    let(:headers) { HTTP::Headers.coerce("Content-Length" => "10") }

    context "when body is nil" do
      let(:body) { nil }

      it "returns nil" do
        expect(subject.deflate(headers, body)).to be_nil
      end

      it "does not remove Content-Length header" do
        subject.deflate(headers, body)
        expect(headers["Content-Length"]).to eq "10"
      end

      it "does not set Content-Encoding header" do
        subject.deflate(headers, body)
        expect(headers.include?("Content-Encoding")).to eq false
      end
    end

    context "when body is not a string" do
      let(:body) { {} }

      it "returns given body" do
        expect(subject.deflate(headers, body).object_id).to eq(body.object_id)
      end

      it "does not remove Content-Length header" do
        subject.deflate(headers, body)
        expect(headers["Content-Length"]).to eq "10"
      end

      it "does not set Content-Encoding header" do
        subject.deflate(headers, body)
        expect(headers.include?("Content-Encoding")).to eq false
      end
    end

    context "when body is a string" do
      let(:body) { "Hello HTTP!" }

      it "encodes body" do
        encoded = subject.deflate(headers, body)
        decoded = Zlib::GzipReader.new(StringIO.new(encoded)).read

        expect(decoded).to eq(body)
      end

      it "removes Content-Length header" do
        subject.deflate(headers, body)
        expect(headers.include?("Content-Length")).to eq false
      end

      it "sets Content-Encoding header" do
        subject.deflate(headers, body)
        expect(headers["Content-Encoding"]).to eq "gzip"
      end

      context "as deflate method" do
        subject { HTTP::Features::AutoDeflate.new(:method => :deflate) }

        it "encodes body" do
          encoded = subject.deflate(headers, body)
          decoded = Zlib::Inflate.inflate(encoded)

          expect(decoded).to eq(body)
        end

        it "removes Content-Length header" do
          subject.deflate(headers, body)
          expect(headers.include?("Content-Length")).to eq false
        end

        it "sets Content-Encoding header" do
          subject.deflate(headers, body)
          expect(headers["Content-Encoding"]).to eq "deflate"
        end
      end
    end
  end
end
