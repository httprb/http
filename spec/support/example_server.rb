require 'webrick'
require 'singleton'
require 'forwardable'

require 'support/example_server/servlet'

class ExampleServer
  extend  Forwardable

  include Singleton

  PORT = 65_432
  ADDR = "127.0.0.1:#{PORT}"

  def initialize
    @server = WEBrick::HTTPServer.new :Port => PORT, :AccessLog => []
    @server.mount '/', Servlet
  end

  delegate [:start, :shutdown] => :@server
end

t = Thread.new { ExampleServer.instance.start }

trap('INT') do
  ExampleServer.instance.shutdown
  exit
end

Thread.pass while t.status && t.status != 'sleep'
