require "support/black_hole"
require "webrick/httpproxy"

def with_proxy(port, handler, options = {})
  proxy = WEBrick::HTTPProxyServer.new({
    :Port => port,
    :AccessLog => [],
    :ProxyContentHandler => handler,
    :Logger => BlackHole
  }.merge(options))

  oversee_webrick_server(proxy) { yield proxy }
end

def with_auth_proxy(port, handler, options = {})
  username = options.fetch(:user)
  password = options.fetch(:password)

  auth_proc = proc do | req, res |
    WEBrick::HTTPAuth.proxy_basic_auth(req, res, "proxy") do |user, pass|
      user == username && pass == password
    end
  end

  with_proxy(port, handler, options.merge(:ProxyAuthProc => auth_proc)) { |proxy| yield proxy }
end

def oversee_webrick_server(server)
  thread = Thread.new { server.start }
  Thread.pass while thread.status != "sleep"

  begin
    yield server
  ensure
    server.shutdown
    thread.join
  end
end
