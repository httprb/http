# frozen_string_literal: true

require "test_helper"

describe HTTP::Response::Body do
  cover "HTTP::Response::Body*"
  let(:body) { HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8) }

  let(:connection) do
    fake(sequence_id: 0, readpartial: proc { chunks.shift || raise(EOFError) }, body_completed?: proc {
      chunks.empty?
    })
  end
  let(:chunks) { ["Hello, ", "World!"] }

  it "streams bodies from responses" do
    result = body.to_s

    assert_equal "Hello, World!", result
    assert_equal Encoding::UTF_8, result.encoding
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
    it "returns the same string on subsequent calls" do
      first  = body.to_s
      second = body.to_s

      assert_equal "Hello, World!", first
      assert_same first, second
    end

    context "when an error occurs during reading" do
      let(:connection) { fake(readpartial: proc { raise IOError, "read error" }) }

      it "re-raises the error and resets contents" do
        assert_raises(IOError) { body.to_s }
      end

      it "raises StateError on subsequent call after error" do
        assert_raises(IOError) { body.to_s }

        err = assert_raises(HTTP::StateError) { body.to_s }
        assert_match(/body is being streamed/, err.message)
      end
    end
  end

  describe "#loggable?" do
    context "with text encoding" do
      let(:body) { HTTP::Response::Body.new(connection, encoding: Encoding::UTF_8) }

      it "returns true" do
        assert_predicate body, :loggable?
      end
    end

    context "with binary encoding" do
      let(:body) { HTTP::Response::Body.new(connection) }

      it "returns false" do
        refute_predicate body, :loggable?
      end
    end
  end

  describe "#connection" do
    context "when stream responds to :connection" do
      it "returns the stream's connection" do
        inner_conn = Object.new
        stream = fake(
          connection:  inner_conn,
          readpartial: proc { raise EOFError }
        )
        b = HTTP::Response::Body.new(stream)

        assert_same inner_conn, b.connection
      end
    end

    context "when stream does not respond to :connection" do
      it "returns the stream itself" do
        stream = fake(readpartial: proc { raise EOFError })
        b = HTTP::Response::Body.new(stream)

        assert_same stream, b.connection
      end
    end
  end

  describe "#initialize" do
    it "explicitly initializes @streaming" do
      assert body.instance_variable_defined?(:@streaming)
    end

    it "explicitly initializes @contents" do
      assert body.instance_variable_defined?(:@contents)
    end
  end

  describe "#inspect" do
    it "includes class name, hex object_id, and streaming state" do
      result = body.inspect
      hex_id = body.object_id.to_s(16)

      assert_equal "#<HTTP::Response::Body:#{hex_id} @streaming=false>", result
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
        assert_raises(EOFError) { body.readpartial }
      end
    end
  end

  context "when inflater receives non-gzip data marked as gzip" do
    let(:body) do
      inflater = HTTP::Response::Inflater.new(connection)
      HTTP::Response::Body.new(inflater, encoding: Encoding::UTF_8)
    end

    let(:chunks) { [" "] }

    it "does not raise Zlib::BufError" do
      assert_equal "", body.to_s
    end
  end

  context "when inflater receives EOFError without prior data" do
    it "closes the zstream and re-raises" do
      conn = fake(readpartial: proc { raise EOFError })
      inflater = HTTP::Response::Inflater.new(conn)

      assert_raises(EOFError) { inflater.readpartial }
    end

    it "handles repeated EOFError after zstream is already closed" do
      conn = fake(readpartial: proc { raise EOFError })
      inflater = HTTP::Response::Inflater.new(conn)

      assert_raises(EOFError) { inflater.readpartial }
      assert_raises(EOFError) { inflater.readpartial }
    end
  end
end
