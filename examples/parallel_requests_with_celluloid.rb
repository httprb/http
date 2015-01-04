#!/usr/bin/env ruby
#
# Example of using the HTTP Gem with Celluloid::IO
# Make sure to 'gem install celluloid-io' before running
#
# Run as: bundle exec examples/parallel_requests_with_celluloid.rb
#

require "celluloid/io"
require "http"

class HttpFetcher
  include Celluloid::IO

  def fetch(url)
    # Note: For SSL support specify:
    # ssl_socket_class: Celluloid::IO::SSLSocket
    HTTP.get(url, :socket_class => Celluloid::IO::TCPSocket)
  end
end

fetcher = HttpFetcher.new

urls = %w(http://ruby-lang.org/ http://rubygems.org/ http://celluloid.io/)

# Kick off a bunch of future calls to HttpFetcher to grab the URLs in parallel
futures = urls.map { |u| [u, fetcher.future.fetch(u)] }

# Consume the results as they come in
futures.each do |url, future|
  # Wait for HttpFetcher#fetch to complete for this request
  response = future.value
  puts "Got #{url}: #{response.inspect}"
end

# Suppress Celluloid's shutdown messages
# Otherwise the example is a bit noisy :|
exit!
