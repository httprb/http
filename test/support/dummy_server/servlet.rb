# frozen_string_literal: true

require "uri"

class DummyServer < WEBrick::HTTPServer
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def self.sockets
      @sockets ||= []
    end

    def not_found(req, res)
      res.status = 404
      res.body   = "#{req.unparsed_uri} not found"
    end

    def self.handlers
      @handlers ||= {}
    end

    def initialize(server, memo)
      super(server)
      @memo = memo
    end

    %w[get post head].each do |method|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{method}(path, &block)
          handlers["#{method}:\#{path}"] = block
        end

        def do_#{method.upcase}(req, res)
          handler = self.class.handlers["#{method}:\#{req.path}"]
          return instance_exec(req, res, &handler) if handler
          not_found(req, res)
        end
      RUBY
    end
  end
end

require "support/dummy_server/routes"
require "support/dummy_server/encoding_routes"
