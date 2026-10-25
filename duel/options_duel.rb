# frozen_string_literal: true

require_relative "duel_helper"

# Chaining options, as in HTTP.headers(...).auth(...).get(...), builds a
# new set of options and a new session at each step.

duel "options: chain headers, auth, accept, timeout" do
  HTTP.headers("X-Request-Id" => "42").auth("Bearer abc123").accept(:json).timeout(5)
end

duel "options: merge a request's options" do
  once do
    @defaults = HTTP::Options.new(headers: { "Accept" => "application/json" }, follow: true)
    @request = { headers: { "Authorization" => "Bearer abc123" }, params: { page: 2 } }
  end
  @defaults.merge(@request)
end
