require 'http'

# Compatibility with the Curb gem
module Curl
  module Err
    class CurlError < RuntimeError; end
    class ConnectionFailedError < CurlError; end
    class HostResolutionError < CurlError; end
  end

  class Easy
    attr_accessor :headers, :encoding
    attr_reader   :response_code, :body_str

    def self.http_post(url, request_body = nil)
      Easy.new(url).tap { |e| e.http_post(request_body) }
    end

    def self.http_get(url, request_body = nil)
      Easy.new(url).tap { |e| e.http_get(request_body) }
    end

    def initialize(url = nil, method = nil, request_body = nil, headers = {})
      @url = url
      @method = method
      @request_body = request_body
      @headers = headers
      @response_code = @body_str = nil
    end

    def perform
      client   = Http::Client.new
      options  = {:response => :object, :headers => @headers}
      response = client.request @method, @url, options
      @response_code, @body_str = response.code, response.body
      true
    rescue SocketError => ex
      if ex.message['getaddrinfo'] || ex.message['ame or service not known']
        raise Err::HostResolutionError, ex.message
      else
        raise Err::ConnectionFailedError, ex.message
      end
    end

    def http_get(request_body = nil)
      @method, @request_body = :get, request_body
      perform
    end

    def http_put(request_body = nil)
      @method, @request_body = :put, request_body
      perform
    end

     def http_post(request_body = nil)
      @method, @request_body = :post, request_body
      perform
    end

    def http_delete
      @method = :delete
      perform
    end
  end

  class Multi
    def initialize
      @clients = []
      @done = false
    end

    def add(client)
      @clients << client
    end


    def perform
      return if @done

      @clients.map do |client|
        Thread.new { client.perform }
      end.each(&:join)

      @done = true
    end
  end
end
