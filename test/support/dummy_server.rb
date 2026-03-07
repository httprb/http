# frozen_string_literal: true

require "socket"
require "openssl"

require "support/dummy_server/servlet"
require "support/servers/runner"
require "support/ssl_helper"

class DummyServer
  def initialize(options = {})
    @ssl        = options[:ssl]
    @tcp_server = TCPServer.new("127.0.0.1", 0)
    @port       = @tcp_server.addr[1]
    @memo       = {}
    @servlet    = Servlet.new(self, @memo)
    @running    = false
  end

  def addr
    "127.0.0.1"
  end

  attr_reader :port

  def endpoint
    "#{scheme}://#{addr}:#{port}"
  end

  def scheme
    @ssl ? "https" : "http"
  end

  def start
    server = @ssl ? ssl_server : @tcp_server
    @running = true

    while @running
      client = server.accept
      Thread.new(client) { |c| handle_connection(c) }
    end
  rescue IOError, Errno::EBADF
    # Server socket closed during shutdown
  end

  def shutdown
    @running = false
    @tcp_server.close
  rescue
    nil
  end

  def ssl_context
    @ssl_context ||= SSLHelper.server_context
  end

  private

  def ssl_server
    OpenSSL::SSL::SSLServer.new(@tcp_server, ssl_context)
  end

  def handle_connection(client)
    loop do
      request = read_request(client)
      break unless request

      Thread.pass
      respond(client, request)
    end
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE, Errno::EPROTOTYPE, OpenSSL::SSL::SSLError
    # Connection closed or SSL error
  ensure
    client.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def respond(client, request)
    response = Response.new
    @servlet.dispatch(request, response)
    client.write(response.serialize(head_request: request.request_method == "HEAD"))
  end

  def read_request(client)
    line = client.gets
    return unless line

    method, uri, = line.split(" ", 3)
    return bad_request(client) unless uri.ascii_only?

    raw_path, query_string = uri.split("?", 2)
    headers = read_headers(client)

    Request.new({
      request_method: method, request_path: percent_decode(raw_path),
      query_string: query_string, headers: headers,
      body: read_body(client, headers), socket: client, unparsed_uri: uri
    })
  end

  def read_headers(client)
    headers = {}
    while (header_line = client.gets)
      break if header_line == "\r\n"

      key, value = header_line.split(": ", 2)
      headers[key.downcase] = value.strip
    end
    headers
  end

  def read_body(client, headers)
    content_length = headers["content-length"]
    client.read(content_length.to_i) if content_length
  end

  def bad_request(client)
    client.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    nil
  end

  def percent_decode(str)
    str.b.gsub(/%([0-9A-Fa-f]{2})/) { [::Regexp.last_match(1)].pack("H2") }
  end
end
