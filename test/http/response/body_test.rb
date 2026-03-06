# frozen_string_literal: true

require "test_helper"

describe HTTP::Response::Body do
  let(:body) { HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8) }

  let(:connection) do
    fake(sequence_id: 0, readpartial: proc { chunks.shift }, body_completed?: proc {
      chunks.empty?
    })
  end
  let(:chunks) { ["Hello, ", "World!"] }

  it "streams bodies from responses" do
    assert_equal "Hello, World!", body.to_s
  end

  context "when body empty" do
    let(:chunks) { [""] }

    it "returns responds to empty? with true" do
      assert_empty body
    end
  end

  describe "#readpartial" do
    context "with size given" do
      it "passes value to underlying connection" do
        received_size = nil
        conn = Object.new
        conn.define_singleton_method(:readpartial) do |size = nil|
          received_size = size
          "data"
        end
        b = HTTP::Response::Body.new(conn, encoding: Encoding::UTF_8)
        b.readpartial(42)

        assert_equal 42, received_size
      end
    end

    context "without size given" do
      it "does not blow up" do
        body.readpartial
      end

      it "calls underlying connection readpartial without specific size" do
        call_args = nil
        conn = Object.new
        conn.define_singleton_method(:readpartial) do |*args|
          call_args = args
          "data"
        end
        b = HTTP::Response::Body.new(conn, encoding: Encoding::UTF_8)
        b.readpartial

        assert_equal [], call_args
      end
    end

    it "returns content in specified encoding" do
      conn1 = fake(readpartial: proc { String.new("content", encoding: Encoding::UTF_8) })
      b1 = HTTP::Response::Body.new(conn1)

      assert_equal Encoding::BINARY, b1.readpartial.encoding

      conn2 = fake(readpartial: proc { String.new("content", encoding: Encoding::BINARY) })
      b2 = HTTP::Response::Body.new(conn2, encoding: Encoding::UTF_8)

      assert_equal Encoding::UTF_8, b2.readpartial.encoding
    end
  end

  describe "#each" do
    it "yields each chunk" do
      collected = body.map { |chunk| chunk }

      assert_equal "Hello, World!", collected.join
    end
  end

  describe "#to_s when streaming" do
    it "raises StateError if body is being streamed" do
      body.readpartial
      err = assert_raises(HTTP::StateError) { body.to_s }
      assert_match(/body is being streamed/, err.message)
    end
  end

  describe "#stream! after consumption" do
    it "raises StateError if body has already been consumed" do
      body.to_s
      err = assert_raises(HTTP::StateError) { body.readpartial }
      assert_match(/body has already been consumed/, err.message)
    end
  end

  describe "#to_s" do
    context "when an error occurs during reading" do
      let(:connection) { fake(readpartial: proc { raise IOError, "read error" }) }

      it "re-raises the error and resets contents" do
        assert_raises(IOError) { body.to_s }
      end
    end
  end

  describe "#inspect" do
    it "includes streaming state" do
      assert_match(/@streaming=false/, body.inspect)
    end
  end

  context "with invalid encoding" do
    let(:body) { HTTP::Response::Body.new(connection, encoding: "nonexistent-encoding") }

    it "falls back to binary encoding" do
      assert_equal Encoding::BINARY, body.to_s.encoding
    end
  end

  context "when body is gzipped" do
    let(:body) do
      inflater = HTTP::Response::Inflater.new(connection)
      HTTP::Response::Body.new(inflater, encoding: Encoding::UTF_8)
    end

    let(:chunks) do
      compressed = Zlib::Deflate.deflate("Hi, HTTP here \u263A")
      len = compressed.length
      [compressed[0, len / 2], compressed[(len / 2)..]]
    end

    it "decodes body" do
      assert_equal "Hi, HTTP here \u263A", body.to_s
    end

    describe "#readpartial" do
      it "streams decoded body" do
        assert_equal "Hi, HTTP ", body.readpartial
        assert_equal "here \u263A", body.readpartial
        assert_nil body.readpartial
      end
    end
  end

  context "when inflater receives nil chunk without prior data" do
    it "closes the zstream and handles subsequent nil" do
      conn = fake(sequence_id: 0, readpartial: proc {}, body_completed?: proc { true })
      inflater = HTTP::Response::Inflater.new(conn)
      inflater.readpartial

      assert_nil inflater.readpartial
    end
  end
end
