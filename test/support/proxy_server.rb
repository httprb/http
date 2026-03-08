# frozen_string_literal: true

require "socket"
require "uri"
require "base64"

require "support/servers/runner"

class ProxyServer
  Target = Struct.new(:host, :port, :path, :query)

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
    method, target, version, headers, body = read_proxy_request(client)
    return unless method && target

    if (response = authenticate(headers))
      client.write(response)
      return
    end

    if method == "CONNECT"
      tunnel_connection(client, target)
    else
      forward_and_respond(client, method, target, body, version)
    end
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE, URI::InvalidURIError
    # Connection closed
  ensure
    client.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def read_proxy_request(client)
    line = client.gets
    return unless line

    method, target, version = line.strip.split(" ", 3)
    headers = read_headers(client)
    body = headers["Content-Length"] ? client.read(headers["Content-Length"].to_i) : nil

    [method, parse_target(method, target), version, headers, body]
  end

  def parse_target(method, target)
    return parse_connect_target(target) if method == "CONNECT"

    uri = URI.parse(target)
    Target.new(host: uri.host, port: uri.port, path: uri.path, query: uri.query)
  end

  def parse_connect_target(target)
    host, port = target.split(":", 2)
    return unless host && port

    Target.new(host: host, port: Integer(port))
  rescue ArgumentError
    nil
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

  def forward_and_respond(client, method, target, body, version)
    target_socket = send_to_target(method, target, body, version)
    relay_response(client, target_socket)
  ensure
    target_socket&.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def send_to_target(method, target, body, version)
    socket = TCPSocket.new(target.host, target.port)
    path = target.path.to_s.empty? ? "/" : target.path
    path = "#{path}?#{target.query}" if target.query

    socket.write("#{method} #{path} #{version}\r\n")
    socket.write("Host: #{target.host}:#{target.port}\r\n")
    socket.write("Content-Length: #{body.bytesize}\r\n") if body
    socket.write("\r\n")
    socket.write(body) if body
    socket
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

  def tunnel_connection(client, target)
    target_socket = TCPSocket.new(target.host, target.port)

    client.write("HTTP/1.1 200 Connection established\r\n\r\n")
    relay_tunnel(client, target_socket)
  ensure
    target_socket&.close rescue nil # rubocop:disable Style/RescueModifier
  end

  def relay_tunnel(client, target)
    [
      Thread.new { copy_stream(client, target) },
      Thread.new { copy_stream(target, client) }
    ].each(&:join)
  end

  def copy_stream(source, destination)
    loop do
      destination.write(source.readpartial(1024))
    end
  rescue IOError, Errno::ECONNRESET, Errno::EPIPE
    nil
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
