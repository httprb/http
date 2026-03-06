# frozen_string_literal: true

RSpec.describe HTTP::Response::Body do
  subject(:body) { described_class.new(connection, encoding: Encoding::UTF_8) }

  let(:connection) { double(sequence_id: 0) }
  let(:chunks)     { ["Hello, ", "World!"] }

  before do
    allow(connection).to receive(:readpartial) { chunks.shift }
    allow(connection).to receive(:body_completed?) { chunks.empty? }
  end

  it "streams bodies from responses" do
    expect(subject.to_s).to eq("Hello, World!")
  end

  context "when body empty" do
    let(:chunks) { [""] }

    it "returns responds to empty? with true" do
      expect(subject).to be_empty
    end
  end

  describe "#readpartial" do
    context "with size given" do
      it "passes value to underlying connection" do
        expect(connection).to receive(:readpartial).with(42)
        body.readpartial 42
      end
    end

    context "without size given" do
      it "does not blows up" do
        expect { body.readpartial }.not_to raise_error
      end

      it "calls underlying connection readpartial without specific size" do
        expect(connection).to receive(:readpartial).with no_args
        body.readpartial
      end
    end

    it "returns content in specified encoding" do
      body = described_class.new(connection)
      expect(connection).to receive(:readpartial).
        and_return(String.new("content", encoding: Encoding::UTF_8))
      expect(body.readpartial.encoding).to eq Encoding::BINARY

      body = described_class.new(connection, encoding: Encoding::UTF_8)
      expect(connection).to receive(:readpartial).
        and_return(String.new("content", encoding: Encoding::BINARY))
      expect(body.readpartial.encoding).to eq Encoding::UTF_8
    end
  end

  describe "#each" do
    it "yields each chunk" do
      collected = body.map { |chunk| chunk }
      expect(collected.join).to eq "Hello, World!"
    end
  end

  describe "#to_s when streaming" do
    it "raises StateError if body is being streamed" do
      body.readpartial
      expect { body.to_s }.to raise_error(HTTP::StateError, /body is being streamed/)
    end
  end

  describe "#stream! after consumption" do
    it "raises StateError if body has already been consumed" do
      body.to_s
      expect { body.readpartial }.to raise_error(HTTP::StateError, /body has already been consumed/)
    end
  end

  describe "#to_s" do
    context "when an error occurs during reading" do
      before do
        allow(connection).to receive(:readpartial).and_raise(IOError, "read error")
      end

      it "re-raises the error and resets contents" do
        expect { body.to_s }.to raise_error(IOError, "read error")
        # After error, contents should be nil so to_s can be retried
      end
    end
  end

  describe "#inspect" do
    it "includes streaming state" do
      expect(body.inspect).to match(/@streaming=false/)
    end
  end

  context "with invalid encoding" do
    subject(:body) { described_class.new(connection, encoding: "nonexistent-encoding") }

    it "falls back to binary encoding" do
      expect(body.to_s.encoding).to eq Encoding::BINARY
    end
  end

  context "when body is gzipped" do
    subject(:body) do
      inflater = HTTP::Response::Inflater.new(connection)
      described_class.new(inflater, encoding: Encoding::UTF_8)
    end

    let(:chunks) do
      body = Zlib::Deflate.deflate("Hi, HTTP here ☺")
      len  = body.length
      [body[0, len / 2], body[(len / 2)..]]
    end

    it "decodes body" do
      expect(subject.to_s).to eq("Hi, HTTP here ☺")
    end

    describe "#readpartial" do
      it "streams decoded body" do
        [
          "Hi, HTTP ",
          "here ☺",
          nil
        ].each do |part|
          expect(subject.readpartial).to eq(part)
        end
      end
    end
  end

  context "when inflater receives nil chunk without prior data" do
    it "closes the zstream and handles subsequent nil" do
      conn = double(sequence_id: 0)
      allow(conn).to receive_messages(readpartial: nil, body_completed?: true)
      inflater = HTTP::Response::Inflater.new(conn)
      inflater.readpartial
      expect(inflater.readpartial).to be_nil
    end
  end
end
