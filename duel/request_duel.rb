# frozen_string_literal: true

require_relative "duel_helper"

# Building a request from options (its URL, headers and body), and
# writing it out, happen once per request. The writes go to a sink in
# memory, not a socket.

duel "request: build a GET" do
  once { @options = HTTP::Options.new }
  HTTP::Request::Builder.new(@options).build(:get, api_url)
end

duel "request: build a GET with query params" do
  once { @options = HTTP::Options.new(params: { q: "ruby http", page: 2, per_page: 50 }) }
  HTTP::Request::Builder.new(@options).build(:get, api_url)
end

duel "request: build a POST with a JSON body" do
  once { @options = HTTP::Options.new(json: { name: "Jane", email: "jane@example.com", tags: %w[a b c], age: 42 }) }
  HTTP::Request::Builder.new(@options).build(:post, api_url)
end

duel "request: build a POST with a form" do
  once { @options = HTTP::Options.new(form: { name: "Jane", email: "jane@example.com", tags: %w[a b c], age: 42 }) }
  HTTP::Request::Builder.new(@options).build(:post, api_url)
end

duel "request: write a GET" do
  once { @request = HTTP::Request::Builder.new(HTTP::Options.new).build(:get, api_url) }
  @request.stream(NullSink.new)
end

duel "request: write a POST with an 8 KB body" do
  once { @request = HTTP::Request.new(verb: :post, uri: api_url, body: text_of(8192)) }
  @request.stream(NullSink.new)
end

duel "request: write a chunked body of 16 KB" do
  once do
    @request = HTTP::Request.new(verb: :post, uri: api_url, headers: { "Transfer-Encoding" => "chunked" },
                                 body: Array.new(16) { text_of(1024) })
  end
  @request.stream(NullSink.new)
end

duel "request: encode a multipart upload of 16 KB" do
  once do
    @file = text_of(16_384)
    @boundary = ("-" * 21) + ("0" * 42) # fixed, where Multipart would pick a random one
  end
  part = HTTP::FormData::Part.new(@file, filename: "notes.txt", content_type: "text/plain")
  HTTP::FormData::Multipart.new({ title: "Notes", file: part }, boundary: @boundary).to_s
end
