# frozen_string_literal: true

class DummyServer < WEBrick::HTTPServer
  class Servlet
    post "/encoded-body" do |req, res|
      res.status = 200

      res.body = case req["Accept-Encoding"]
                 when "gzip"
                   res["Content-Encoding"] = "gzip"
                   StringIO.open do |out|
                     Zlib::GzipWriter.wrap(out) do |gz|
                       gz.write "#{req.body}-gzipped"
                       gz.finish
                       out.tap(&:rewind).read
                     end
                   end
                 when "deflate"
                   res["Content-Encoding"] = "deflate"
                   Zlib::Deflate.deflate("#{req.body}-deflated")
                 else
                   "#{req.body}-raw"
                 end
    end

    post "/no-content-204" do |req, res|
      res.status = 204
      res.body   = ""

      case req["Accept-Encoding"]
      when "gzip"
        res["Content-Encoding"] = "gzip"
      when "deflate"
        res["Content-Encoding"] = "deflate"
      end
    end

    get "/retry-2" do |_req, res|
      @memo[:attempts] ||= 0
      @memo[:attempts] += 1

      res.body = "retried #{@memo[:attempts]}x"
      res.status = @memo[:attempts] == 2 ? 200 : 500
    end
  end
end
