# frozen_string_literal: true

require_relative "duel_helper"

# Whole requests, end to end: the session and client, building and
# writing the request, parsing the response, any features, and reading
# the body. A MemoryServer (see duel_helper.rb) serves fixed responses
# from memory, so nothing waits on a socket.

duel "client: GET a JSON response" do
  once do
    server = MemoryServer.new(http_response(json_document(10), headers: api_response_headers))
    @http = HTTP::Session.new(socket_class: server)
    @http.get(api_url).to_s
  end
  @http.get(api_url).to_s
end

duel "client: POST JSON and parse the reply" do
  once do
    server = MemoryServer.new(http_response(json_document(10), status: "201 Created", headers: api_response_headers))
    @http = HTTP::Session.new(socket_class: server)
    @body = { name: "Jane", email: "jane@example.com", tags: %w[a b c] }
    @http.post(api_url, json: @body).parse
  end
  @http.post(api_url, json: @body).parse
end

# Streamed, as a large body is read: reading it whole grows one string
# by reallocating it, whose cost varies with each process's heap.
duel "client: stream a 128 KB body" do
  once do
    server = MemoryServer.new(http_response(text_of(1 << 17), headers: { "Content-Type" => "text/plain" }))
    @http = HTTP::Session.new(socket_class: server)
    @http.get(api_url).body.each { |_chunk| nil }
  end
  @http.get(api_url).body.each { |_chunk| nil }
end

duel "client: GET a chunked body" do
  once do
    bytes = http_response(json_document(100), headers: api_response_headers, chunks: 1024)
    @http = HTTP::Session.new(socket_class: MemoryServer.new(bytes))
    @http.get(api_url).to_s
  end
  @http.get(api_url).to_s
end

duel "client: GET on a persistent connection" do
  once do
    server = MemoryServer.new(http_response(json_document(10), headers: api_response_headers))
    # A long keep-alive, so the one connection is reused by every request.
    @http = HTTP::Session.new(socket_class: server).persistent("http://api.example.com", timeout: 86_400)
    @http.get("/v1/users/42").to_s
  end
  @http.get("/v1/users/42").to_s
end

duel "client: GET a gzipped body with auto_inflate" do
  once do
    headers = api_response_headers.merge("Content-Encoding" => "gzip")
    server = MemoryServer.new(http_response(gzip(json_document(500)), headers: headers))
    @http = HTTP::Session.new(socket_class: server).use(:auto_inflate)
    @http.get(api_url).to_s
  end
  @http.get(api_url).to_s
end

duel "client: follow a redirect" do
  once do
    server = MemoryServer.new(
      http_response("", status: "302 Found", headers: { "Location" => "/v2/users/42" }),
      http_response(json_document(10), headers: api_response_headers)
    )
    @http = HTTP::Session.new(socket_class: server).follow
    @http.get(api_url).to_s
  end
  @http.get(api_url).to_s
end

loopback = lambda do
  @server = LoopbackServer.new(http_response(json_document(10), headers: api_response_headers))
  @http = HTTP::Session.new(socket_class: @server)
end

# Through the kernel, so judged on its counts alone.
duel "client: GET over a loopback TCP connection",
     only: :count, setup: loopback, before_sample: -> { @server.close_peers }, teardown: -> { @server.close } do
  @http.get(api_url).to_s
end
