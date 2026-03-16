# frozen_string_literal: true

require "socket"
require "openssl"

require "support/dummy_server/servlet"
require "support/servers/runner"
require "support/ssl_helper"

class DummyServer
  def initialize(ssl: false)
    @ssl        = ssl
    @tcp_server = TCPServer.new("127.0.0.1", 0)
    @port       = @tcp_server.addr[1]
    @memo       = {}
    @servlet    = Servlet.new(self, @memo)
    @running    = false
    @ready      = Queue.new
    ssl_context if @ssl
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

  def wait_ready
    @ready.pop
  end

  def start
    server = @ssl ? OpenSSL::SSL::SSLServer.new(@tcp_server, ssl_context) : @tcp_server
    @running = true
    @ready << true

    while @running
      begin
        client = server.accept
      rescue OpenSSL::SSL::SSLError
        next
      end
      Thread.new(client) { |c| handle_connection(c) }
    end
  rescue IOError, Errno::EBADF
    # Server socket closed during shutdown
  end

  def reset
    @memo.clear
    Servlet.sockets.clear
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

  # Simple HTTP request object for route handlers
  Request = Struct.new(:request_method, :path, :query_string, :unparsed_uri,
                       :headers, :body, :socket) do
    def [](name)
      headers.each { |k, v| return v if k.casecmp?(name) }
      nil
    end

    def cookies
      cookie_header = self["Cookie"]
      return [] unless cookie_header

      cookie_header.split("; ").map do |pair|
        name, value = pair.split("=", 2)
        DummyServer::Cookie.new(name, value || "")
      end
    end
  end

  # Simple HTTP response object for route handlers
  class Response
    attr_accessor :status
    attr_accessor :body
    attr_accessor :cookies

    def initialize
      @status  = 200
      @body    = ""
      @headers = {}
      @cookies = []
    end

    def []=(name, value)
      @headers[name] = value
    end

    def [](name)
      @headers[name]
    end

    def serialize(head_request: false)
      lines = ["HTTP/1.1 #{status} #{STATUS_TEXT.fetch(status, 'Unknown')}"]

      cookies.each do |cookie|
        value = "#{cookie.name}=#{cookie.value}"
        value += "; path=#{cookie.path}" if cookie.path
        lines << "Set-Cookie: #{value}"
      end

      @headers.each { |k, v| lines << "#{k}: #{v}" }

      body_bytes = body.to_s.b
      lines << "Content-Length: #{body_bytes.bytesize}" unless @headers.key?("Content-Length")

      header_str = lines.join("\r\n") << "\r\n\r\n"
      head_request ? header_str : header_str << body_bytes
    end

    STATUS_TEXT = {
      200 => "OK", 204 => "No Content", 301 => "Moved Permanently",
      302 => "Found", 400 => "Bad Request", 404 => "Not Found",
      407 => "Proxy Authentication Required", 500 => "Internal Server Error"
    }.freeze
  end

  Cookie    = Struct.new(:name, :value)
  SetCookie = Struct.new(:name, :value, :path)

  private

  def handle_connection(client)
    loop do
      request = read_request(client)
      break unless request

      response = Response.new
      @servlet.service(request, response)
      client.write(response.serialize(head_request: request.request_method == "HEAD"))
      break unless response["Connection"]&.casecmp?("keep-alive")
    end
  rescue IOError, Errno::EBADF, Errno::ECONNRESET, Errno::EPIPE, Errno::EPROTOTYPE, OpenSSL::SSL::SSLError
    # Connection closed or SSL error
  ensure
    client.close rescue nil
  end

  def read_request(client)
    line = client.gets
    return unless line

    method, uri, = line.split(" ", 3)
    return bad_request(client) unless uri&.ascii_only?

    raw_path, query_string = uri.split("?", 2)
    headers = read_headers(client)

    Request.new(
      request_method: method, path: percent_decode(raw_path),
      query_string: query_string, headers: headers,
      body: read_body(client, headers), socket: client, unparsed_uri: uri
    )
  end

  def read_headers(client)
    headers = {}
    while (header_line = client.gets)
      break if header_line == "\r\n"

      key, value = header_line.split(": ", 2)
      headers[key] = value.strip if key && value
    end
    headers
  end

  def read_body(client, headers)
    content_length = headers["Content-Length"]
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
