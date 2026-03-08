# frozen_string_literal: true

require "test_helper"

describe HTTP::Request::Body do
  cover "HTTP::Request::Body*"
  let(:subject_under_test) { HTTP::Request::Body.new(body) }

  let(:body) { "" }

  describe "#initialize" do
    context "when body is nil" do
      let(:body) { nil }

      it "does not raise an error" do
        HTTP::Request::Body.new(body)
      end
    end

    context "when body is a string" do
      let(:body) { "string body" }

      it "does not raise an error" do
        HTTP::Request::Body.new(body)
      end
    end

    context "when body is an IO" do
      let(:body) { FakeIO.new("IO body") }

      it "does not raise an error" do
        HTTP::Request::Body.new(body)
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w[bees cows] }

      it "does not raise an error" do
        HTTP::Request::Body.new(body)
      end
    end

    context "when body is of unrecognized type" do
      let(:body) { 123 }

      it "raises an error" do
        assert_raises(HTTP::RequestError) { HTTP::Request::Body.new(body) }
      end
    end
  end

  describe "#source" do
    it "returns the original object" do
      assert_equal "", subject_under_test.source
    end
  end

  describe "#size" do
    context "when body is nil" do
      let(:body) { nil }

      it "returns zero" do
        assert_equal 0, subject_under_test.size
      end
    end

    context "when body is a string" do
      let(:body) { "\u041F\u0440\u0438\u0432\u0435\u0442, \u043C\u0438\u0440!" }

      it "returns string bytesize" do
        assert_equal 21, subject_under_test.size
      end
    end

    context "when body is an IO with size" do
      let(:body) { FakeIO.new("content") }

      it "returns IO size" do
        assert_equal 7, subject_under_test.size
      end
    end

    context "when body is an IO without size" do
      let(:body) { IO.pipe[0] }

      it "raises a RequestError" do
        assert_raises(HTTP::RequestError) { subject_under_test.size }
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w[bees cows] }

      it "raises a RequestError" do
        assert_raises(HTTP::RequestError) { subject_under_test.size }
      end
    end
  end

  describe "#empty?" do
    context "when body is nil" do
      let(:body) { nil }

      it "returns true" do
        assert_predicate subject_under_test, :empty?
      end
    end

    context "when body is a string" do
      let(:body) { "content" }

      it "returns false" do
        refute_predicate subject_under_test, :empty?
      end
    end

    context "when body is an empty string" do
      let(:body) { "" }

      it "returns false" do
        refute_predicate subject_under_test, :empty?
      end
    end
  end

  describe "#each" do
    let(:chunks) do
      subject_under_test.enum_for(:each).map(&:dup)
    end

    context "when body is nil" do
      let(:body) { nil }

      it "yields nothing" do
        assert_equal [], chunks
      end
    end

    context "when body is a string" do
      let(:body) { "content" }

      it "yields the string" do
        assert_equal %w[content], chunks
      end
    end

    context "when body is a non-Enumerable IO" do
      let(:body) { FakeIO.new(("a" * 16 * 1024) + ("b" * 10 * 1024)) }

      it "yields chunks of content" do
        assert_equal ("a" * 16 * 1024) + ("b" * 10 * 1024), chunks.sum("")
      end
    end

    context "when body is a pipe" do
      let(:ios)  { IO.pipe }
      let(:body) { ios[0] }

      it "yields chunks of content" do
        writer = Thread.new(ios[1]) do |io|
          io << "abcdef"
          io.close
        end

        begin
          assert_equal "abcdef", chunks.sum("")
        ensure
          writer.join
        end
      end
    end

    context "when body is an Enumerable IO" do
      let(:data) { ("a" * 16 * 1024) + ("b" * 10 * 1024) }
      let(:body) { StringIO.new data }

      it "yields chunks of content" do
        assert_equal data, chunks.sum("")
      end

      it "allows to enumerate multiple times" do
        results = []

        2.times do
          result = ""
          subject_under_test.each { |chunk| result += chunk }
          results << result
        end

        assert_equal 2, results.count
        assert(results.all?(data))
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w[bees cows] }

      it "yields elements" do
        assert_equal %w[bees cows], chunks
      end
    end
  end

  describe "#==" do
    context "when sources are equivalent" do
      let(:body1) { HTTP::Request::Body.new("content") }
      let(:body2) { HTTP::Request::Body.new("content") }

      it "returns true" do
        assert_equal body1, body2
      end
    end

    context "when sources are not equivalent" do
      let(:body1) { HTTP::Request::Body.new("content") }
      let(:body2) { HTTP::Request::Body.new(nil) }

      it "returns false" do
        refute_equal body1, body2
      end
    end

    context "when objects are not of the same class" do
      let(:body1) { HTTP::Request::Body.new("content") }
      let(:body2) { "content" }

      it "returns false" do
        refute_equal body1, body2
      end
    end

    context "when sources are both truthy but different" do
      let(:body1) { HTTP::Request::Body.new("alpha") }
      let(:body2) { HTTP::Request::Body.new("beta") }

      it "returns false" do
        refute_equal body1, body2
      end
    end
  end

  describe "#each return value" do
    context "when body is a string" do
      let(:body) { "content" }

      it "returns self" do
        assert_same(subject_under_test, subject_under_test.each { |_| nil })
      end
    end

    context "when body is nil" do
      let(:body) { nil }

      it "returns self" do
        assert_same(subject_under_test, subject_under_test.each { |_| nil })
      end
    end

    context "when body is an IO" do
      let(:body) { StringIO.new("io content") }

      it "returns self" do
        assert_same(subject_under_test, subject_under_test.each { |_| nil })
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w[bees cows] }

      it "returns self" do
        assert_same(subject_under_test, subject_under_test.each { |_| nil })
      end
    end
  end

  describe "#size error messages" do
    context "when body is an IO without #size" do
      let(:body) { IO.pipe[0] }

      it "raises RequestError with message about IO needing #size" do
        err = assert_raises(HTTP::RequestError) { subject_under_test.size }
        assert_match(/IO object must respond to #size/, err.message)
      end
    end

    context "when body is an Enumerable" do
      let(:body) { %w[bees cows] }

      it "raises RequestError with message about undetermined size including inspect" do
        err = assert_raises(HTTP::RequestError) { subject_under_test.size }
        assert_match(/cannot determine size of body/, err.message)
        assert_includes err.message, body.inspect
        assert_match(/Content-Length/, err.message)
        assert_match(/chunked Transfer-Encoding/, err.message)
      end
    end
  end

  describe "#initialize error messages" do
    context "when body is of unrecognized type" do
      it "raises RequestError mentioning wrong type and class name" do
        err = assert_raises(HTTP::RequestError) { HTTP::Request::Body.new(123) }
        assert_match(/body of wrong type/, err.message)
        assert_match(/Integer/, err.message)
      end
    end
  end

  context "when body is a String subclass" do
    let(:string_subclass) { Class.new(String) }
    let(:body) { string_subclass.new("subclass body") }

    it "does not raise on initialization" do
      HTTP::Request::Body.new(body)
    end

    it "returns correct size" do
      assert_equal 13, subject_under_test.size
    end

    it "yields the string in #each" do
      chunks = subject_under_test.enum_for(:each).map(&:dup)

      assert_equal ["subclass body"], chunks
    end
  end

  context "when comparing with a Body subclass" do
    it "returns true for equivalent subclass instance" do
      subclass = Class.new(HTTP::Request::Body)
      body1 = HTTP::Request::Body.new("content")
      body2 = subclass.new("content")

      assert_equal body1, body2
    end
  end

  describe HTTP::Request::Body::ProcIO do
    describe "#write" do
      it "calls the block with data and returns bytesize" do
        received = nil
        block = proc { |data| received = data }
        proc_io = HTTP::Request::Body::ProcIO.new(block)

        result = proc_io.write("hello")

        assert_equal "hello", received
        assert_equal 5, result
      end

      it "returns correct bytesize for multibyte strings" do
        block = proc { |_| }
        proc_io = HTTP::Request::Body::ProcIO.new(block)

        # "Привет" is 12 bytes in UTF-8
        result = proc_io.write("\u041F\u0440\u0438\u0432\u0435\u0442")

        assert_equal 12, result
      end
    end
  end
end
