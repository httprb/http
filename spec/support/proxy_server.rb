require 'webrick/httpproxy'

ProxyServer     = WEBrick::HTTPProxyServer.new(:Port => 8080, :AccessLog => [])

t = Thread.new { ProxyServer.start }
trap("INT")    { ProxyServer.shutdown; exit }

AuthenticatedProxyServer = WEBrick::HTTPProxyServer.new(:Port => 8081,
                  :ProxyAuthProc => Proc.new do | req, res |
                    WEBrick::HTTPAuth.proxy_basic_auth(req, res, 'proxy') do | user, pass |
                      user == 'username' and pass == 'password'
                    end
                  end)


t = Thread.new { AuthenticatedProxyServer.start }
trap("INT")    { AuthenticatedProxyServer.shutdown; exit }
