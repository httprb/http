# frozen_string_literal: true

require "socket"
require "openssl"

require "support/proxy_server"
require "support/ssl_helper"

# Serves each accepted connection with the next handler of a script
#
# Handlers receive a {Peer} and decide how the connection behaves: answer,
# close with or without a TLS close_notify, reset, or stall. Connections past
# the end of the script reuse the last handler.
class ScriptedServer
  OK = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"

  # The server side of one accepted connection
  class Peer
    def initialize(server, socket)
      @server = server
      @socket = socket
    end

    def read_request
      head = +""
      while (line = @socket.gets)
        head << line
        break if line == "\r\n"
      end
      return if head.empty?

      length = head[/^Content-Length: (\d+)/i, 1].to_i
      head << @socket.read(length) if length.positive?
      @server.record(head)
    end

    def write(data)
      @socket.write(data)
    end

    def respond
      write(OK)
    end

    def serve
      respond while read_request
    end

    # Closes the TCP socket without a TLS close_notify
    def fin
      @socket.to_io.close
      @server.closed
    end

    def close_notify
      @socket.close
      @server.closed
    end

    def reset
      @socket.to_io.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [1, 0].pack("ii"))
      fin
    end
  end

  attr_reader :accepts

  def initialize(*handlers, ssl: false)
    @handlers    = handlers
    @ssl_context = SSLHelper.server_context if ssl
    @tcp_server  = TCPServer.new("127.0.0.1", 0)
    @accepts     = 0
    @requests    = []
    @sockets     = []
    @lock        = Mutex.new
    @closed      = Queue.new
    @thread      = Thread.new { accept_loop }
  end

  def endpoint
    "#{@ssl_context ? 'https' : 'http'}://127.0.0.1:#{@tcp_server.addr[1]}"
  end

  def requests
    @lock.synchronize { @requests.dup }
  end

  def record(request)
    @lock.synchronize { @requests << request }
    request
  end

  def closed
    @closed << true
  end

  def wait_closed
    @closed.pop(timeout: 5) || raise("no connection was closed")
  end

  def shutdown
    @tcp_server.close
    @thread.join
    @lock.synchronize { @sockets.each { |socket| socket.to_io.close unless socket.to_io.closed? } }
  end

  private

  def accept_loop
    loop do
      socket  = @tcp_server.accept
      handler = @handlers[[@accepts, @handlers.size - 1].min]
      @accepts += 1
      Thread.new { handle(socket, handler) }
    end
  rescue IOError, SystemCallError
    nil
  end

  def handle(socket, handler)
    socket = upgrade(socket) if @ssl_context
    @lock.synchronize { @sockets << socket }
    handler.call(Peer.new(self, socket))
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    nil
  end

  def upgrade(socket)
    ssl = OpenSSL::SSL::SSLSocket.new(socket, @ssl_context)
    ssl.sync_close = true
    ssl.accept
  end
end

# A proxy that can drop its open CONNECT tunnels the way an idle timeout does
class TunnelClosingProxy < ProxyServer
  attr_reader :connects

  def initialize
    super
    @connects = 0
    @tunnels  = Queue.new
  end

  def close_tunnels
    @tunnels.pop.close until @tunnels.empty?
  end

  private

  def tunnel_connection(client, target)
    @connects += 1
    @tunnels << client
    super
  end
end
