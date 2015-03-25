class DummyServer < WEBrick::HTTPServer
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def not_found(_req, res)
      res.status = 404
      res.body   = 'Not Found'
    end

    def self.handlers
      @handlers ||= {}
    end

    %w[get post head].each do |method|
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

    get '/' do |_req, res|
      res.status = 200
      res.body   = '<!doctype html>'
    end
  end
end
