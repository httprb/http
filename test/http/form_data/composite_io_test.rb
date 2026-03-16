# frozen_string_literal: true

require "test_helper"

class FormDataCompositeIOTest < Minitest::Test
  cover "HTTP::FormData::CompositeIO*"

  def setup
    @ios = ["Hello", " ", "", "world", "!"].map { |s| StringIO.new(s) }
    @composite_io = HTTP::FormData::CompositeIO.new(@ios)
  end

  def test_accepts_ios_and_strings
    io = HTTP::FormData::CompositeIO.new(["Hello ", StringIO.new("world!")])

    assert_equal "Hello world!", io.read
  end

  def test_rejects_invalid_io_types
    error = assert_raises(ArgumentError) { HTTP::FormData::CompositeIO.new(%i[hello world]) }

    assert_includes error.message, ":hello"
    assert_includes error.message, "is neither a String nor an IO object"
  end

  def test_error_message_contains_inspect
    obj = Object.new
    def obj.inspect = "INVALID_IO_INSPECT"
    def obj.to_s = "INVALID_IO_TO_S"

    error = assert_raises(ArgumentError) { HTTP::FormData::CompositeIO.new([obj]) }

    assert_includes error.message, "INVALID_IO_INSPECT"
  end

  def test_reads_all_data
    assert_equal "Hello world!", @composite_io.read
  end

  def test_reads_partial_data
    assert_equal "Hel", @composite_io.read(3)
    assert_equal "lo", @composite_io.read(2)
    assert_equal " ", @composite_io.read(1)
    assert_equal "world!", @composite_io.read(6)
  end

  def test_returns_empty_string_when_exhausted_without_length
    @composite_io.read

    assert_equal "", @composite_io.read
  end

  def test_returns_nil_when_exhausted_with_length
    @composite_io.read

    assert_nil @composite_io.read(3)
  end

  def test_reads_partial_data_with_buffer
    outbuf = +""

    assert_equal "Hel", @composite_io.read(3, outbuf)
    assert_equal "lo", @composite_io.read(2, outbuf)
    assert_equal " ", @composite_io.read(1, outbuf)
    assert_equal "world!", @composite_io.read(6, outbuf)
  end

  def test_fills_buffer_with_retrieved_content
    outbuf = +""
    @composite_io.read(3, outbuf)

    assert_equal "Hel", outbuf
    @composite_io.read(2, outbuf)

    assert_equal "lo", outbuf
    @composite_io.read(1, outbuf)

    assert_equal " ", outbuf
    @composite_io.read(6, outbuf)

    assert_equal "world!", outbuf
  end

  def test_clears_buffer_when_exhausted_with_length
    outbuf = +"content"
    @composite_io.read

    assert_nil @composite_io.read(3, outbuf)
    assert_equal "", outbuf
  end

  def test_returns_binary_encoding
    io = HTTP::FormData::CompositeIO.new(%w[Janko Marohnić])

    assert_equal Encoding::BINARY, io.read(5).encoding
    assert_equal Encoding::BINARY, io.read(9).encoding

    io.rewind

    assert_equal Encoding::BINARY, io.read.encoding
    assert_equal Encoding::BINARY, io.read.encoding
  end

  def test_reads_data_in_bytes
    emoji = "😃"
    io = HTTP::FormData::CompositeIO.new([emoji])

    assert_equal emoji.b[0], io.read(1)
    assert_equal emoji.b[1], io.read(1)
    assert_equal emoji.b[2], io.read(1)
    assert_equal emoji.b[3], io.read(1)
  end

  def test_rewinds_all_ios
    @composite_io.read
    @composite_io.rewind

    assert_equal "Hello world!", @composite_io.read
  end

  def test_size_returns_sum_of_all_ios
    assert_equal 12, @composite_io.size
  end

  def test_size_returns_zero_for_empty
    assert_equal 0, HTTP::FormData::CompositeIO.new([]).size
  end

  def test_accepts_string_subclass
    io = HTTP::FormData::CompositeIO.new([Class.new(String).new("hello")])

    assert_equal "hello", io.read
  end

  def test_accepts_custom_io_object
    custom_io = Class.new do
      def initialize = @done = false

      def read(length = nil, outbuf = nil)
        if @done
          length ? nil : ""
        else
          @done = true
          result = +"custom"
          outbuf ? outbuf.replace(result) : result
        end
      end

      def size = 6
      def rewind = @done = false
    end.new

    assert_equal "custom", HTTP::FormData::CompositeIO.new([custom_io]).read
  end

  def test_starts_reading_from_beginning
    assert_equal "a", HTTP::FormData::CompositeIO.new(%w[abc def]).read(1)
  end

  def test_reads_across_io_boundaries
    io = HTTP::FormData::CompositeIO.new(%w[abc def])

    assert_equal "ab", io.read(2)
    assert_equal "cd", io.read(2)
    assert_equal "ef", io.read(2)
  end

  def test_skips_empty_io_in_middle
    assert_equal "abcd", HTTP::FormData::CompositeIO.new(["ab", "", "cd"]).read
  end

  def test_respects_length_exactly
    io = HTTP::FormData::CompositeIO.new(%w[abcdef ghijkl])

    assert_equal "abc", io.read(3)
    assert_equal "def", io.read(3)
    assert_equal "ghi", io.read(3)
    assert_equal "jkl", io.read(3)
    assert_nil io.read(1)
  end

  def test_length_spanning_ios
    io = HTTP::FormData::CompositeIO.new(%w[ab cd ef])

    assert_equal "abcd", io.read(4)
    assert_equal "ef", io.read(4)
  end

  def test_read_all_with_outbuf
    outbuf = +""
    io = HTTP::FormData::CompositeIO.new(["hello", " ", "world"])
    result = io.read(nil, outbuf)

    assert_equal "hello world", result
    assert_equal "hello world", outbuf
    assert_same result, outbuf
  end

  def test_read_with_outbuf_clears_previous_content
    outbuf = +"previous content"
    io = HTTP::FormData::CompositeIO.new(["new"])
    io.read(nil, outbuf)

    assert_equal "new", outbuf
  end

  def test_outbuf_encoding_forced_to_binary
    outbuf = +"hello"
    outbuf.force_encoding(Encoding::UTF_8)
    io = HTTP::FormData::CompositeIO.new(%w[Marohnić])
    io.read(5, outbuf)

    assert_equal Encoding::BINARY, outbuf.encoding
  end
end
