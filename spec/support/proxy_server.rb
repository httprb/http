require 'webrick/httpproxy'

handler = proc do | req, res |
  res['X-PROXIED'] = true
end

ProxyServer = WEBrick::HTTPProxyServer.new(
  :Port => 8080,
  :AccessLog => [],
  :RequestCallback => handler
)

AuthenticatedProxyServer = WEBrick::HTTPProxyServer.new(
  :Port => 8081,
  :ProxyAuthProc => proc do | req, res |
    WEBrick::HTTPAuth.proxy_basic_auth(req, res, 'proxy') do | user, pass |
      user == 'username' && pass == 'password'
    end
  end,
  :RequestCallback => handler
)

Thread.new  { ProxyServer.start }
trap('INT') do
  ProxyServer.shutdown
  exit
end

Thread.new  { AuthenticatedProxyServer.start }
trap('INT') do
  AuthenticatedProxyServer.shutdown
  exit
end
