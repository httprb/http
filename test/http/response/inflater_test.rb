# frozen_string_literal: true

require "test_helper"
require "zlib"

class HTTPResponseInflaterTest < Minitest::Test
  cover "HTTP::Response::Inflater*"

  def build_connection(chunks)
    fake(readpartial: proc { chunks.shift || raise(EOFError) })
  end

  def gzip(payload)
    Zlib.gzip(payload)
  end

  # Split a string into chunks of +size+ bytes
  def chunk(string, size)
    string.bytes.each_slice(size).map { |bytes| bytes.pack("C*") }
  end

  # ---------------------------------------------------------------------------
  # basic decompression
  # ---------------------------------------------------------------------------

  def test_decompresses_gzip_response
    compressed = gzip("hello world")
    connection = build_connection([compressed])
    inflater = HTTP::Response::Inflater.new(connection)

    assert_equal "hello world", inflater.readpartial
  end

  # ---------------------------------------------------------------------------
  # never returns empty string
  # ---------------------------------------------------------------------------

  def test_skips_empty_inflate_output
    payload = "hello world"
    compressed_chunks = chunk(gzip(payload), 3)
    connection = build_connection(compressed_chunks)
    inflater = HTTP::Response::Inflater.new(connection)

    result = +""
    begin
      loop do
        part = inflater.readpartial
        refute_empty part, "readpartial must never return an empty string"
        result << part
      end
    rescue EOFError
      # expected
    end

    assert_equal payload, result
  end

  # ---------------------------------------------------------------------------
  # respects maxlen
  # ---------------------------------------------------------------------------

  def test_readpartial_respects_size_limit
    payload = "a" * 1000
    # Use small chunks so decompression produces output larger than the chunk size
    compressed_chunks = chunk(gzip(payload), 16)
    connection = build_connection(compressed_chunks)
    inflater = HTTP::Response::Inflater.new(connection)

    max = 64
    result = +""
    begin
      loop do
        part = inflater.readpartial(max)
        assert part.bytesize <= max, "readpartial(#{max}) returned #{part.bytesize} bytes"
        refute_empty part
        result << part
      end
    rescue EOFError
      # expected
    end

    assert_equal payload, result
  end

  # ---------------------------------------------------------------------------
  # forwards size to connection
  # ---------------------------------------------------------------------------

  def test_forwards_size_to_connection
    [2, 4096].each do |size|
      compressed = gzip("hello world")
      received_sizes = []
      connection = fake(readpartial: proc { |*args|
        received_sizes << args.first
        compressed.slice!(0, compressed.bytesize).tap { |c| raise EOFError if c.nil? || c.empty? }
      })
      inflater = HTTP::Response::Inflater.new(connection)

      begin
        loop { inflater.readpartial(size) }
      rescue EOFError
        # expected
      end

      assert(received_sizes.all? { |s| s == size }, "expected #{size} to be forwarded to connection, got: #{received_sizes.inspect}")
    end
  end

  # ---------------------------------------------------------------------------
  # size larger than inflated output
  # ---------------------------------------------------------------------------

  def test_returns_chunk_directly_when_smaller_than_size
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    # size is much larger than the decompressed output
    result = inflater.readpartial(4096)
    assert_equal payload, result
  end

  def test_does_not_buffer_when_inflated_fits_in_size
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    inflater.readpartial(4096)
    assert_predicate inflater.instance_variable_get(:@buffer), :empty?
  end

  # ---------------------------------------------------------------------------
  # connection returning empty/nil does not infinite loop
  # ---------------------------------------------------------------------------

  def test_raises_eof_when_connection_returns_empty_string
    connection = fake(readpartial: proc { "" })
    inflater = HTTP::Response::Inflater.new(connection)

    assert_raises(EOFError) { inflater.readpartial }
  end

  def test_raises_eof_when_connection_returns_nil
    connection = fake(readpartial: proc { nil })
    inflater = HTTP::Response::Inflater.new(connection)

    assert_raises(EOFError) { inflater.readpartial }
  end

  # ---------------------------------------------------------------------------
  # EOF with buffered data
  # ---------------------------------------------------------------------------

  def test_returns_buffered_data_before_eof
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    # Read one byte at a time to force buffering
    result = +""
    begin
      loop { result << inflater.readpartial(1) }
    rescue EOFError
      # expected
    end

    assert_equal payload, result
  end

  # ---------------------------------------------------------------------------
  # size larger than total decompressed output
  # ---------------------------------------------------------------------------

  def test_decompresses_fully_when_size_exceeds_output
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    result = +""
    begin
      loop { result << inflater.readpartial(4096) }
    rescue EOFError
      # expected
    end

    assert_equal payload, result
  end

  # ---------------------------------------------------------------------------
  # zstream cleanup on EOF
  # ---------------------------------------------------------------------------

  def test_closes_zstream_on_eof
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    begin
      loop { inflater.readpartial(1) }
    rescue EOFError
      # expected
    end

    assert_predicate inflater.send(:zstream), :closed?
  end

  def test_closes_zstream_on_eof_without_size
    payload = "hello world"
    connection = build_connection([gzip(payload)])
    inflater = HTTP::Response::Inflater.new(connection)

    begin
      loop { inflater.readpartial }
    rescue EOFError
      # expected
    end

    assert_predicate inflater.send(:zstream), :closed?
  end
end
