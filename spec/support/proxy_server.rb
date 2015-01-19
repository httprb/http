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

RSpec.configure do |config|
  servers = [
    ProxyServer,
    AuthenticatedProxyServer
  ]
  threads = []

  config.before :suite do
    threads.push(*servers.map { |server| Thread.new { server.start } })
    # wait until servers fully boot up
    Thread.pass while threads.any? { |t| t.status && t.status != "sleep" }
  end

  config.after :suite do
    servers.each { |server| server.shutdown }
    threads.each(&:join).clear
  end
end
