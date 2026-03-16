# frozen_string_literal: true

require "uri"

class DummyServer
  class Servlet
    def self.sockets
      @sockets ||= []
    end

    def initialize(server, memo)
      @server = server
      @memo   = memo
    end

    def service(req, res)
      method  = req.request_method.downcase
      handler = self.class.routes["#{method}:#{req.path}"]

      if handler
        instance_exec(req, res, &handler)
      else
        res.status = 404
        res.body   = "#{req.unparsed_uri} not found"
      end

      res["Connection"] = "keep-alive"
    end

    class << self
      def routes
        @routes ||= {}
      end

      %w[get post head].each do |method|
        define_method(method) do |path, &block|
          routes["#{method}:#{path}"] = block
        end
      end
    end

    private

    def request_body(req)
      req.body
    end

    def request_header(req, name)
      req[name]
    end

    def request_cookies(req)
      req.cookies
    end

    def query_string(req)
      req.query_string
    end

    def query_params(req)
      if req.body && req["Content-Type"]&.include?("application/x-www-form-urlencoded")
        URI.decode_www_form(req.body).to_h
      elsif req.query_string && !req.query_string.empty?
        URI.decode_www_form(req.query_string).to_h
      else
        {}
      end
    end

    def server_addr
      @server.addr
    end

    def server_port
      @server.port
    end
  end
end

require "support/dummy_server/routes"
require "support/dummy_server/encoding_routes"
