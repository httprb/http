require 'webrick'

class ExampleServer
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def not_found(_req, res)
      res.status = 404
      res.body   = 'Not Found'
    end

    def self.handlers
      @handlers ||= {}
    end

    %w(get post head).each do |method|
      class_eval <<-RUBY, __FILE__, __LINE__
        def self.#{method}(path, &block)
          handlers["#{method}:\#{path}"] = block
        end

        def do_#{method.upcase}(req, res)
          handler = self.class.handlers["#{method}:\#{req.path}"]
          return instance_exec(req, res, &handler) if handler
          not_found
        end
      RUBY
    end

    get '/' do |req, res|
      res.status = 200

      case req['Accept']
      when 'application/json'
        res['Content-Type'] = 'application/json'
        res.body = '{"json": true}'
      else
        res['Content-Type'] = 'text/html'
        res.body   = '<!doctype html>'
      end
    end

    get '/params' do |req, res|
      next not_found unless 'foo=bar' == req.query_string

      res.status = 200
      res.body   = 'Params!'
    end

    get '/multiple-params' do |req, res|
      params = CGI.parse req.query_string

      next not_found unless {'foo' => ['bar'], 'baz' => ['quux']} == params

      res.status = 200
      res.body   = 'More Params!'
    end

    get '/proxy' do |_req, res|
      res.status = 200
      res.body   = 'Proxy!'
    end

    get '/not-found' do |_req, res|
      res.status = 404
      res.body   = 'not found'
    end

    get '/redirect-301' do |_req, res|
      res.status      = 301
      res['Location'] = "http://#{ExampleServer::ADDR}/"
    end

    get '/redirect-302' do |_req, res|
      res.status      = 302
      res['Location'] = "http://#{ExampleServer::ADDR}/"
    end

    post '/form' do |req, res|
      if 'testing-form' == req.query['example']
        res.status = 200
        res.body   = 'passed :)'
      else
        res.status = 400
        res.body   = 'invalid! >:E'
      end
    end

    post '/body' do |req, res|
      if 'testing-body' == req.body
        res.status = 200
        res.body   = 'passed :)'
      else
        res.status = 400
        res.body   = 'invalid! >:E'
      end
    end

    head '/' do |_req, res|
      res.status          = 200
      res['Content-Type'] = 'text/html'
    end
  end
end
