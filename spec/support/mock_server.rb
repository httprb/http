require 'webrick'

TEST_SERVER_PORT = 65432

class MockService < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    case request.path
    when "/"
      response.status = 200
      
      case request['Accept']
      when 'application/json'
        response['Content-Type'] = 'application/json'
        response.body = '{"json": true}'
      else
        response['Content-Type'] = 'text/html'
        response.body   = "<!doctype html>"
      end
    else
      response.status = 404
    end
  end
  
  def do_POST(request, response)
    case request.path
    when "/"
      if request.query['example'] == 'testing'
        response.status = 200
        response.body   = "passed :)"
      else
        response.status = 400
        response.body   = "invalid! >:E"
      end
    else
      response.status = 404
    end
  end
  
  def do_HEAD(request, response)
    case request.path
    when "/"
      response.status = 200
      response['Content-Type'] = 'text/html'
    else
      response.status = 404
    end
  end
end

MockServer = WEBrick::HTTPServer.new(:Port => TEST_SERVER_PORT, :AccessLog => [])
MockServer.mount "/", MockService

t = Thread.new { MockServer.start }
trap("INT")    { MockServer.shutdown; exit }

Thread.pass while t.status and t.status != "sleep"