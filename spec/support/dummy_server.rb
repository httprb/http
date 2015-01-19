require "webrick"
require "forwardable"

require "support/black_hole"
require "support/dummy_server/servlet"
require "support/helpers/server_runner"

class DummyServer
  extend  Forwardable

  CONFIG = {:BindAddress => "127.0.0.1", :Port => 0, :Logger => BlackHole}.freeze

  def initialize
    @server = WEBrick::HTTPServer.new CONFIG
    @server.mount("/", Servlet)
  end

  def endpoint
    "http://#{@server.config[:BindAddress]}:#{@server.config[:Port]}"
  end

  def_delegators :@server, :start, :shutdown
end
