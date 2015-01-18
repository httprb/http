require "webrick/httpproxy"

handler = proc { |_, res| res["X-PROXIED"] = true }

ProxyServer = WEBrick::HTTPProxyServer.new(
  :Port => 8080,
  :AccessLog => [],
  :RequestCallback => handler
)

AuthenticatedProxyServer = WEBrick::HTTPProxyServer.new(
  :Port => 8081,
  :ProxyAuthProc => proc do | req, res |
    WEBrick::HTTPAuth.proxy_basic_auth(req, res, "proxy") do | user, pass |
      user == "username" && pass == "password"
    end
  end,
  :RequestCallback => handler
)
