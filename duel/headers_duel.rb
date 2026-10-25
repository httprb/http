# frozen_string_literal: true

require_relative "duel_helper"

# Every request builds its headers, and every response's headers are
# looked up by name. Names are normalized through a per-thread cache,
# which each benchmark warms in `once`.

duel "headers: build 5 from a hash" do
  once do
    @hash = { "Accept" => "application/json", "Authorization" => "Bearer abc123",
              "User-Agent" => "MyApp/1.0", :content_type => "text/plain", "X-Request-Id" => "42" }
    HTTP::Headers.coerce(@hash)
  end
  HTTP::Headers.coerce(@hash)
end

duel "headers: build 50 from a hash" do
  once do
    @hash = Array.new(50) { |i| ["X-Custom-Header-#{i}", "value-#{i}"] }.to_h
    HTTP::Headers.coerce(@hash)
  end
  HTTP::Headers.coerce(@hash)
end

duel "headers: look up a response's headers" do
  once { @headers = HTTP::Headers.coerce(api_response_headers) }
  @headers["Content-Type"]
  @headers["ETag"]
  @headers.get("Vary")
  @headers.include?("Transfer-Encoding")
end

duel "headers: merge request headers" do
  once do
    @defaults = HTTP::Headers.coerce("Accept" => "application/json", "User-Agent" => "MyApp/1.0")
    @extra = { "Authorization" => "Bearer abc123", "Accept" => "text/html", "X-Request-Id" => "42" }
    @defaults.merge(@extra)
  end
  @defaults.merge(@extra)
end
