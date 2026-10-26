# frozen_string_literal: true

require "socket"
require "stringio"
require "zlib"

# A stand-in for a server, for the socket_class option: each connection
# that the client opens serves the next of a fixed list of responses from
# memory. No system calls, so the client's whole round trip (building and
# writing the request, parsing the response, and reading its body) runs
# in Ruby and times steadily.
class MemoryServer
  def initialize(*responses)
    @responses = responses.map { |response| response.b.freeze }
    @next = 0
  end

  def open(_host, _port)
    response = @responses.fetch(@next)
    @next = (@next + 1) % @responses.size
    MemorySocket.new(response)
  end
end

# One connection to a MemoryServer. It discards what the client writes.
# Each request that it's sent starts the same response again, so a
# persistent connection gets a fresh one for every request.
class MemorySocket
  def initialize(response)
    @response = response
    @offset = response.bytesize
    @closed = false
  end

  def write(data)
    @offset = 0
    data.bytesize
  end

  def readpartial(size, buffer = nil)
    raise EOFError if @offset >= @response.bytesize

    chunk = @response.byteslice(@offset, size)
    @offset += chunk.bytesize
    buffer ? buffer.replace(chunk) : chunk
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end

# Where a request is written to: it counts the bytes and keeps none.
class NullSink
  attr_reader :bytes

  def initialize
    @bytes = 0
  end

  def write(data)
    @bytes += data.bytesize
    data.bytesize
  end
  alias << write
end

# The bytes of an HTTP/1.1 response with these headers and body. With
# chunks, the body is sent chunked, in chunks of that many bytes.
def http_response(body = "", status: "200 OK", headers: {}, chunks: nil)
  head = "HTTP/1.1 #{status}\r\n"
  headers.each { |name, value| head << "#{name}: #{value}\r\n" }
  if chunks
    head << "Transfer-Encoding: chunked\r\n\r\n"
    slices(body.b, chunks).each { |chunk| head << "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n" }
    head << "0\r\n\r\n"
  else
    head << "Content-Length: #{body.bytesize}\r\n\r\n" << body.b
  end
  head.b
end

# The string, in slices of up to this many bytes.
def slices(string, size)
  (0...string.bytesize).step(size).map { |offset| string.byteslice(offset, size) }
end

# The headers of a typical response from an API.
def api_response_headers
  {
    "Date"                      => "Sat, 24 Oct 2026 12:00:00 GMT",
    "Content-Type"              => "application/json; charset=utf-8",
    "Cache-Control"             => "max-age=0, private, must-revalidate",
    "ETag"                      => 'W/"5d41402abc4b2a76b9719d911017c592"',
    "Vary"                      => "Accept, Accept-Encoding",
    "X-Request-Id"              => "0f8fad5b-d9cb-469f-a165-70867728950e",
    "X-Runtime"                 => "0.012345",
    "Strict-Transport-Security" => "max-age=31536000; includeSubDomains"
  }
end

# A JSON document of this many records, about 100 bytes each.
def json_document(records)
  items = Array.new(records) do |i|
    %({"id":#{i},"name":"user#{i}","email":"user#{i}@example.com","active":true,"score":#{(i * 7) % 100}})
  end
  "[#{items.join(',')}]"
end

# Text of this many bytes, the same every time.
def text_of(bytes)
  line = "The quick brown fox jumps over the lazy dog. 0123456789\n"
  (line * ((bytes / line.bytesize) + 1)).byteslice(0, bytes)
end

def gzip(string)
  io = StringIO.new(+"")
  gz = Zlib::GzipWriter.new(io)
  gz.mtime = 0
  gz.write(string)
  gz.close
  io.string
end

# The URL that requests go to. Plain http, as a MemoryServer speaks no
# TLS.
def api_url
  "http://api.example.com/v1/users/42?include=posts&page=2"
end

# A real TCP server on the loopback interface, served from the
# benchmark's own thread: each connection that the client opens is
# accepted at once and sent a fixed response, before the client writes
# its request. Only for benchmarks judged on counts, as system calls time
# too unsteadily.
class LoopbackServer
  def initialize(response)
    @response = response.b.freeze
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @peers = []
  end

  def open(_host, _port)
    socket = TCPSocket.open("127.0.0.1", @port)
    peer = @server.accept
    peer.write(@response)
    @peers << peer
    socket
  end

  # Closes the server's ends of the connections so far.
  def close_peers
    @peers.each(&:close).clear
  end

  def close
    close_peers
    @server.close
  end
end
