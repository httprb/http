# frozen_string_literal: true

class DummyServer
  class Servlet
    get "/" do |req, res|
      res.status = 200

      case req["Accept"]
      when "application/json"
        res["Content-Type"] = "application/json"
        res.body = '{"json": true}'
      else
        res["Content-Type"] = "text/html"
        res.body = "<!doctype html>"
      end
    end

    get "/sleep" do |_req, res|
      sleep 0.02

      res.status = 200
      res.body   = "hello"
    end

    post "/sleep" do |_req, res|
      sleep 0.02

      res.status = 200
      res.body   = "hello"
    end

    ["", "/1", "/2"].each do |path|
      get "/socket#{path}" do |req, res|
        socket = req.socket
        self.class.sockets << socket
        res.status = 200
        res.body   = socket.object_id.to_s
      end
    end

    get "/params" do |req, res|
      if "foo=bar" == query_string(req)
        res.status = 200
        res.body   = "Params!"
      else
        res.status = 404
        res.body   = "#{req.unparsed_uri} not found"
      end
    end

    get "/multiple-params" do |req, res|
      params = URI.decode_www_form(query_string(req)).group_by(&:first).transform_values { |v| v.map(&:last) }

      if { "foo" => ["bar"], "baz" => ["quux"] } == params
        res.status = 200
        res.body   = "More Params!"
      else
        res.status = 404
        res.body   = "#{req.unparsed_uri} not found"
      end
    end

    get "/proxy" do |_req, res|
      res.status = 200
      res.body   = "Proxy!"
    end

    get "/not-found" do |_req, res|
      res.status = 404
      res.body   = "not found"
    end

    get "/redirect-301" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/"
    end

    get "/redirect-302" do |_req, res|
      res.status      = 302
      res["Location"] = "http://#{server_addr}:#{server_port}/"
    end

    post "/form" do |req, res|
      if "testing-form" == query_params(req)["example"]
        res.status = 200
        res.body   = "passed :)"
      else
        res.status = 400
        res.body   = "invalid! >:E"
      end
    end

    post "/body" do |req, res|
      if "testing-body" == request_body(req)
        res.status = 200
        res.body   = "passed :)"
      else
        res.status = 400
        res.body   = "invalid! >:E"
      end
    end

    head "/" do |_req, res|
      res.status          = 200
      res["Content-Type"] = "text/html"
    end

    get "/bytes" do |_req, res|
      bytes = [80, 75, 3, 4, 20, 0, 0, 0, 8, 0, 123, 104, 169, 70, 99, 243, 243]
      res["Content-Type"] = "application/octet-stream"
      res.body = bytes.pack("c*")
    end

    get "/iso-8859-1" do |_req, res|
      res["Content-Type"] = "text/plain; charset=ISO-8859-1"
      res.body = "testæ".encode(Encoding::ISO8859_1)
    end

    get "/cookies" do |req, res|
      cookies = request_cookies(req)
      res.cookies << SetCookie.new("foo", "bar")
      res.body = cookies.map { |c| [c.name, c.value].join ": " }.join("\n")
    end

    post "/echo-body" do |req, res|
      res.status = 200
      res.body   = request_body(req)
    end

    get "/héllö-wörld".b do |_req, res|
      res.status = 200
      res.body   = "hello world"
    end

    get "/echo-cookies" do |req, res|
      res.status = 200
      cookies = request_cookies(req)
      res.body = cookies.map { |c| "#{c.name}=#{c.value}" }.join("; ")
    end

    get "/redirect-with-cookie" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/echo-cookies"
      res.cookies << SetCookie.new("from_redirect", "yes", "/")
    end

    get "/redirect-cookie-chain/1" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/redirect-cookie-chain/2"
      res.cookies << SetCookie.new("first", "1", "/")
    end

    get "/redirect-cookie-chain/2" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/echo-cookies"
      res.cookies << SetCookie.new("second", "2", "/")
    end

    get "/redirect-set-then-delete/1" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/redirect-set-then-delete/2"
      res.cookies << SetCookie.new("temp", "present", "/")
    end

    get "/redirect-set-then-delete/2" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/echo-cookies"
      res.cookies << SetCookie.new("temp", "", "/")
    end

    get "/redirect-no-cookies" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{server_addr}:#{server_port}/echo-cookies"
    end

    get "/cookie-loop" do |req, res|
      cookies = request_cookies(req)
      if cookies.any? { |c| c.name == "auth" && c.value == "ok" }
        res.status = 200
        res.body   = "authenticated"
      else
        res.status = 302
        res["Location"] = "http://#{server_addr}:#{server_port}/cookie-loop"
        res.cookies << SetCookie.new("auth", "ok", "/")
      end
    end

    get "/cross-origin-redirect" do |req, res|
      target = query_params(req)["target"]
      res.status      = 302
      res["Location"] = target
    end

    get "/cross-origin-redirect-with-cookie" do |req, res|
      target = query_params(req)["target"]
      res.status      = 302
      res["Location"] = target
      res.cookies << SetCookie.new("from_origin", "yes", "/")
    end
  end
end
