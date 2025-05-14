#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "http"

# SOCKS5 proxy details
proxy_host = "98.170.57.241"
proxy_port = 4145

begin
  # Make the request through SOCKS5 proxy
  response = HTTP
             .via_socks5(proxy_host, proxy_port)
             .get("http://ifconfig.me/ip")

  puts "Response status: #{response.status}"
  puts "Response body: #{response.body}"
rescue => e
  puts "Error: #{e.class} - #{e.message}"
  puts e.backtrace
end
