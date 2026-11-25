# frozen_string_literal: true

require "test_helper"
require "zlib"
require "stringio"

class HTTPResponseInflaterTest < Minitest::Test
  cover "HTTP::Response::Inflater*"

  # Upper bound on decompressed bytes from one 1 KiB slice of deflate input
  MAX_CHUNK_SIZE = 1_024 * 1_032

  def gzip(data)
    io = StringIO.new("".b)
    gz = Zlib::GzipWriter.new(io)
    gz.write(data)
    gz.close
    io.string
  end

  def connection_for(chunks, reads: [])
    fake(readpartial: proc { |*args|
      reads << args
      chunks.shift || raise(EOFError)
    })
  end

  def read_all(inflater)
    parts = []
    loop { parts << inflater.readpartial }
  rescue EOFError
    parts
  end

  def test_bounds_each_chunk_inflated_from_a_highly_compressed_read
    data = "\0" * (16 * 1_024 * 1_024)
    inflater = HTTP::Response::Inflater.new(connection_for([gzip(data)]))
    parts = read_all(inflater)

    assert_operator parts.map(&:bytesize).max, :<=, MAX_CHUNK_SIZE
    assert_equal data.bytesize, parts.sum(&:bytesize)
  end

  def test_inflates_data_split_across_slices_and_reads
    data = Random.new(42).bytes(5_000) * 3
    compressed = gzip(data)
    chunks = [compressed[0, 3_000], compressed[3_000..]]
    inflater = HTTP::Response::Inflater.new(connection_for(chunks))

    assert_equal data, read_all(inflater).join
  end

  def test_consumes_pending_input_before_reading_the_connection_again
    data = Random.new(42).bytes(10_000)
    reads = []
    inflater = HTTP::Response::Inflater.new(connection_for([gzip(data)], reads: reads))

    inflater.readpartial
    inflater.readpartial

    assert_equal 1, reads.size
  end

  def test_keeps_reading_when_a_slice_yields_no_output
    compressed = gzip("hello")
    chunks = [compressed[0, 10], compressed[10..]]
    inflater = HTTP::Response::Inflater.new(connection_for(chunks))

    assert_equal "hello", inflater.readpartial
  end

  def test_forwards_read_arguments_to_the_connection
    reads = []
    inflater = HTTP::Response::Inflater.new(connection_for([gzip("hello")], reads: reads))

    inflater.readpartial(512)

    assert_equal [[512]], reads
  end

  def test_copies_reads_so_a_reused_outbuf_cannot_corrupt_pending_input
    data = Random.new(42).bytes(10_000)
    compressed = gzip(data)
    outbuf = +""
    conn = fake(readpartial: proc { |_size, buf|
      raise EOFError if compressed.empty?

      buf.replace(compressed)
      compressed = ""
      buf
    })
    inflater = HTTP::Response::Inflater.new(conn)
    parts = [inflater.readpartial(16_384, outbuf)]
    outbuf.replace("garbage")
    parts.concat(read_all(inflater))

    assert_equal data, parts.join
  end
end
