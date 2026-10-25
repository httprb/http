# frozen_string_literal: true

require_relative "duel_helper"

# Every request parses and normalizes its URL, and every redirect joins
# the Location header onto the URL that it came from.

duel "uri: parse a typical URL" do
  once { @url = "https://api.example.com/v1/users/42?include=posts&page=2" }
  HTTP::URI.parse(@url)
end

duel "uri: normalize a typical URL" do
  once { @url = "https://api.example.com/v1/users/42?include=posts&page=2" }
  HTTP::URI::NORMALIZER.call(@url)
end

duel "uri: normalize case, port and dot segments" do
  once { @url = "HTTP://Api.Example.COM:80/v1/users/../teams/./42/../../orgs/7?x=1" }
  HTTP::URI::NORMALIZER.call(@url)
end

duel "uri: normalize a URL with a 2 KB query" do
  once { @url = "https://api.example.com/search?#{Array.new(100) { |i| "key#{i}=value#{i}abc" }.join('&')}" }
  HTTP::URI::NORMALIZER.call(@url)
end

duel "uri: join a relative redirect" do
  once { @base = HTTP::URI.parse("https://api.example.com/v1/users/42?include=posts") }
  @base.join("../orgs/7?page=3")
end
