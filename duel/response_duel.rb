# frozen_string_literal: true

require_relative "duel_helper"

# Parsing a response from fixed bytes with llhttp, the way a connection
# feeds it: one read of up to Connection::BUFFER_SIZE (16 KB), then the
# body taken out. A connection keeps its parser and resets it for each
# response, as these do. (Large bodies are guarded by "client: stream a
# 128 KB body": parsing one alone is mostly copying memory, which times
# too unsteadily to judge.)

duel "response: parse a small response" do
  once do
    @parser = HTTP::Response::Parser.new
    @bytes = http_response("OK", headers: { "Content-Type" => "text/plain" })
  end
  @parser.reset
  @parser << @bytes
  @parser.read(HTTP::Connection::BUFFER_SIZE)
end

duel "response: parse 30 headers and a JSON body" do
  once do
    @parser = HTTP::Response::Parser.new
    headers = api_response_headers.merge(Array.new(22) { |i| ["X-Header-#{i}", "value #{i}"] }.to_h)
    @bytes = http_response(json_document(10), headers: headers)
  end
  @parser.reset
  @parser << @bytes
  @parser.read(HTTP::Connection::BUFFER_SIZE)
end

duel "response: parse a chunked body of 16 KB" do
  once do
    @parser = HTTP::Response::Parser.new
    @bytes = http_response(text_of(16_384), headers: { "Content-Type" => "text/plain" }, chunks: 1024)
  end
  @parser.reset
  @parser << @bytes
  @parser.read(HTTP::Connection::BUFFER_SIZE)
end

duel "response: build one and read its metadata" do
  once do
    @request = HTTP::Request.new(verb: :get, uri: "https://api.example.com/v1/users/42")
    @headers = api_response_headers.merge("Content-Length" => "512")
  end
  response = HTTP::Response.new(status: 200, version: "1.1", headers: @headers, body: "", request: @request)
  response.mime_type
  response.charset
  response.content_length
  response.chunked?
  response.status.success?
end
