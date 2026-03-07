# frozen_string_literal: true

require "uri"

class DummyServer
  Cookie = Struct.new(:name, :value)

  class Request
    attr_reader :request_method
    attr_reader :path
    attr_reader :query_string
    attr_reader :body
    attr_reader :unparsed_uri

    def initialize(attrs)
      @request_method = attrs[:request_method]
      @path           = attrs[:request_path]
      @query_string   = attrs[:query_string]
      @headers        = attrs[:headers]
      @body           = attrs[:body]
      @socket         = attrs[:socket]
      @unparsed_uri   = attrs[:unparsed_uri]
    end

    def [](header)
      @headers[header.downcase]
    end

    def query
      @query ||= if body && @headers["content-type"]&.include?("application/x-www-form-urlencoded")
                   URI.decode_www_form(body).to_h
                 elsif query_string
                   URI.decode_www_form(query_string).to_h
                 else
                   {}
                 end
    end

    def cookies
      @cookies ||= parse_cookies
    end

    private

    def parse_cookies
      cookie_header = @headers["cookie"]
      return [] unless cookie_header

      cookie_header.split("; ").map do |pair|
        name, value = pair.split("=", 2)
        Cookie.new(name, value)
      end
    end
  end

  class Response
    attr_accessor :status
    attr_accessor :body

    STATUS_TEXTS = {
      200 => "OK",
      204 => "No Content",
      301 => "Moved Permanently",
      302 => "Found",
      400 => "Bad Request",
      404 => "Not Found",
      500 => "Internal Server Error"
    }.freeze

    def initialize
      @status  = 200
      @headers = {}
      @body    = ""
    end

    def []=(header, value)
      @headers[header] = value
    end

    def [](header)
      @headers[header]
    end

    def serialize(head_request: false)
      status_text = STATUS_TEXTS[@status] || "OK"
      body_bytes  = @body.to_s.b

      lines = "HTTP/1.1 #{@status} #{status_text}\r\n"
      @headers.each { |k, v| lines << "#{k}: #{v}\r\n" }
      lines << "Content-Length: #{body_bytes.bytesize}\r\n" unless @headers.key?("Content-Length")
      lines << "Connection: keep-alive\r\n"
      lines << "\r\n"
      lines << body_bytes unless head_request
      lines
    end
  end

  class Servlet
    def self.sockets
      @sockets ||= []
    end

    def self.handlers
      @handlers ||= {}
    end

    def initialize(server, memo)
      @server = server
      @memo   = memo
    end

    def not_found(req, res)
      res.status = 404
      res.body   = "#{req.unparsed_uri} not found"
    end

    def dispatch(req, res)
      method  = req.request_method.downcase
      handler = self.class.handlers["#{method}:#{req.path}"]

      if handler
        instance_exec(req, res, &handler)
      else
        not_found(req, res)
      end
    end

    %w[get post head].each do |method|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{method}(path, &block)
          handlers["#{method}:\#{path}"] = block
        end
      RUBY
    end
  end
end

require "support/dummy_server/routes"
require "support/dummy_server/encoding_routes"
