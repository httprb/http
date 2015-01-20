require "webrick"

require "support/black_hole"
require "support/dummy_server/servlet"
require "support/servers/config"
require "support/servers/runner"

class DummyServer < WEBrick::HTTPServer
  include ServerConfig

  CONFIG = {
    :BindAddress  => "127.0.0.1",
    :Port         => 0,
    :AccessLog    => BlackHole,
    :Logger       => BlackHole
  }.freeze

  def initialize
    super CONFIG
    mount("/", Servlet)
  end

  def endpoint
    "http://#{addr}:#{port}"
  end
end
