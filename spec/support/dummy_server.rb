require 'webrick'
require 'webrick/ssl'

require 'support/black_hole'
require 'support/dummy_server/servlet'
require 'support/servers/config'
require 'support/servers/runner'

class DummyServer < WEBrick::HTTPServer
  include ServerConfig

  CONFIG = {
    :BindAddress  => '127.0.0.1',
    :Port         => 0,
    :AccessLog    => BlackHole,
    :Logger       => BlackHole
  }.freeze

  def initialize(options = {})
    if options[:ssl]
      override_config = {
        :SSLEnable            => true,
        :SSLStartImmediately  => true
      }
    else
      override_config = {}
    end

    super CONFIG.merge(override_config)

    mount('/', Servlet)
  end

  def endpoint
    "#{ssl? ? 'https' : 'http'}://#{addr}:#{port}"
  end

  def ssl_context
    @ssl_context ||= begin
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      context.key = OpenSSL::PKey::RSA.new(
        File.read(File.join(certs_dir, 'server.key'))
      )
      context.cert = OpenSSL::X509::Certificate.new(
        File.read(File.join(certs_dir, 'server.crt'))
      )
      context.ca_file = File.join(certs_dir, 'ca.crt')
      context
    end
  end
end
