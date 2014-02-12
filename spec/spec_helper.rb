require 'simplecov'
require 'coveralls'
require 'support/example_response'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage(80)
end

require 'http'
require 'support/example_server'
require 'support/proxy_server'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def capture_warning
  begin
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    result = $stderr.string
  ensure
    $stderr = old_stderr
  end
  result
end

def with_socket_pair
  host = '127.0.0.1'
  port = 10101

  server = TCPServer.new(host, port)
  client = TCPSocket.new(host, port)
  peer   = server.accept

  begin
    yield client, peer
  ensure
    server.close rescue nil
    client.close rescue nil
    peer.close   rescue nil
  end
end
