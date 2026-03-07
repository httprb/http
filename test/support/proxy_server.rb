# frozen_string_literal: true

require "socket"
require "uri"
require "base64"

require "support/servers/runner"

class ProxyServer
  def initialize
    @tcp_server = TCPServer.new("127.0.0.1", 0)
    @port       = @tcp_server.addr[1]
    @running    = false
  end

  def addr
    "127.0.0.1"
  end

  attr_reader :port

  def start
    @running = true

    while @running
      client = @tcp_server.accept
      Thread.new(client) { |c| handle_request(c) }
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

  private

  def handle_request(client)
    method, uri, version, headers, body = read_proxy_request(client)
    return unless method

    if (response = authenticate(headers))
      client.write(response)
      return
    end

    forward_and_respond(client, method, uri, body, version)
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE
    # Connection closed
  ensure
    client.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def read_proxy_request(client)
    line = client.gets
    return unless line

    method, url, version = line.strip.split(" ", 3)
    headers = read_headers(client)
    body = headers["Content-Length"] ? client.read(headers["Content-Length"].to_i) : nil

    [method, URI.parse(url), version, headers, body]
  end

  def read_headers(client)
    headers = {}
    while (header_line = client.gets)
      break if header_line == "\r\n"

      key, value = header_line.split(": ", 2)
      headers[key] = value.strip
    end
    headers
  end

  def authenticate(_headers)
    nil
  end

  def forward_and_respond(client, method, uri, body, version)
    target = send_to_target(method, uri, body, version)
    relay_response(client, target)
  ensure
    target&.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def send_to_target(method, uri, body, version)
    target = TCPSocket.new(uri.host, uri.port)
    path = uri.path.empty? ? "/" : uri.path
    path = "#{path}?#{uri.query}" if uri.query

    target.write("#{method} #{path} #{version}\r\n")
    target.write("Host: #{uri.host}:#{uri.port}\r\n")
    target.write("Content-Length: #{body.bytesize}\r\n") if body
    target.write("\r\n")
    target.write(body) if body
    target
  end

  def relay_response(client, target)
    response_line = target.gets
    return unless response_line

    headers, content_length = read_response_headers(target)
    body = content_length&.positive? ? target.read(content_length) : ""

    client.write("#{response_line}X-PROXIED: true\r\n#{headers}\r\n#{body}")
  rescue IOError, Errno::ECONNRESET
    # Target connection error
  end

  def read_response_headers(target)
    headers = +""
    content_length = nil
    while (hl = target.gets)
      break if hl == "\r\n"

      content_length = ::Regexp.last_match(1).to_i if hl =~ /^Content-Length:\s*(\d+)/i
      headers << hl
    end
    [headers, content_length]
  end
end

class AuthProxyServer < ProxyServer
  private

  def authenticate(headers)
    auth = headers["Proxy-Authorization"]

    if auth
      encoded = auth.sub(/^Basic\s+/, "")
      user, pass = Base64.decode64(encoded).split(":", 2)
      return if user == "username" && pass == "password"
    end

    "HTTP/1.1 407 Proxy Authentication Required\r\n" \
      "Proxy-Authenticate: Basic realm=\"proxy\"\r\n" \
      "Content-Length: 0\r\n" \
      "\r\n"
  end
end
