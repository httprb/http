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

    get "/sleep" do |_, res|
      sleep 0.05

      res.status = 200
      res.body   = "hello"
    end

    post "/sleep" do |_, res|
      sleep 0.05

      res.status = 200
      res.body   = "hello"
    end

    ["", "/1", "/2"].each do |path|
      get "/socket#{path}" do |req, res|
        self.class.sockets << req.instance_variable_get(:@socket)
        res.status  = 200
        res.body    = req.instance_variable_get(:@socket).object_id.to_s
      end
    end

    get "/params" do |req, res|
      next not_found(req, res) unless "foo=bar" == req.query_string

      res.status = 200
      res.body   = "Params!"
    end

    get "/multiple-params" do |req, res|
      params = URI.decode_www_form(req.query_string).group_by(&:first).transform_values { |v| v.map(&:last) }

      next not_found(req, res) unless { "foo" => ["bar"], "baz" => ["quux"] } == params

      res.status = 200
      res.body   = "More Params!"
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
      res["Location"] = "http://#{@server.addr}:#{@server.port}/"
    end

    get "/redirect-302" do |_req, res|
      res.status      = 302
      res["Location"] = "http://#{@server.addr}:#{@server.port}/"
    end

    post "/form" do |req, res|
      if "testing-form" == req.query["example"]
        res.status = 200
        res.body   = "passed :)"
      else
        res.status = 400
        res.body   = "invalid! >:E"
      end
    end

    post "/body" do |req, res|
      if "testing-body" == req.body
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
      res["Set-Cookie"] = "foo=bar"
      res.body = req.cookies.map { |c| [c.name, c.value].join ": " }.join("\n")
    end

    post "/echo-body" do |req, res|
      res.status = 200
      res.body   = req.body
    end

    get "/héllö-wörld".b do |_req, res|
      res.status = 200
      res.body   = "hello world"
    end

    get "/echo-cookies" do |req, res|
      res.status = 200
      res.body   = req.cookies.map { |c| "#{c.name}=#{c.value}" }.join("; ")
    end

    get "/redirect-with-cookie" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/echo-cookies"
      res["Set-Cookie"] = "from_redirect=yes; path=/"
    end

    get "/redirect-cookie-chain/1" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/redirect-cookie-chain/2"
      res["Set-Cookie"] = "first=1; path=/"
    end

    get "/redirect-cookie-chain/2" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/echo-cookies"
      res["Set-Cookie"] = "second=2; path=/"
    end

    get "/redirect-set-then-delete/1" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/redirect-set-then-delete/2"
      res["Set-Cookie"] = "temp=present; path=/"
    end

    get "/redirect-set-then-delete/2" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/echo-cookies"
      res["Set-Cookie"] = "temp=; path=/"
    end

    get "/redirect-no-cookies" do |_req, res|
      res.status      = 301
      res["Location"] = "http://#{@server.addr}:#{@server.port}/echo-cookies"
    end
  end
end
