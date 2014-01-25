require 'webrick/httpproxy'

ProxyServer = WEBrick::HTTPProxyServer.new(:Port => 8080, :AccessLog => [])

Thread.new  { ProxyServer.start }
trap('INT') { ProxyServer.shutdown; exit }

AuthenticatedProxyServer = WEBrick::HTTPProxyServer.new(
  :Port => 8081,
  :ProxyAuthProc => proc do | req, res |
    WEBrick::HTTPAuth.proxy_basic_auth(req, res, 'proxy') do | user, pass |
      user == 'username' && pass == 'password'
    end
  end
)

Thread.new  { AuthenticatedProxyServer.start }
trap('INT') { AuthenticatedProxyServer.shutdown; exit }
