#!/usr/bin/env ruby
#
# Example of using the HTTP Gem with Celluloid::IO
# Make sure to 'gem install celluloid-io' before running
#
# Run as: bundle exec examples/parallel_requests_with_celluloid.rb
#

require 'celluloid/io'
require 'http'

class HttpFetcher
  include Celluloid::IO

  def initialize
    # Follow HTTP redirects and set socket classes to Celluloid::IO ones
    @options = HTTP::Options.new(follow: true, socket_class: Celluloid::IO::TCPSocket, ssl_socket_class: Celluloid::IO::SSLSocket)
  end

  # Calls the Condition block as soon as we get a response
  def fetch(url, blk)
    blk.call(url: url, response: HTTP.get(url, @options).response)
  end
end

class ParallelFetcher
  include Celluloid

  def parallel_fetch(urls, http_fetcher)
    # See Celluloid::Condition https://github.com/celluloid/celluloid/wiki/Conditions
    # Conditions have the advantage that they are processed the the order they are completed
    # unlike Futures which get processed in the order they are started
    condition = Condition.new

    blk = lambda { |result| condition.signal(result) }

    # Fires off a bunch of parallel HTTP gets
    fetchers = urls.map { |url| http_fetcher.async.fetch(url, blk) }

    # Consume the results as they come in
    fetchers.each do |url|
      result = condition.wait
      puts "Got url: #{result[:url]}, response: #{result[:response].inspect}"
    end
  end
end

ParallelFetcher.new.parallel_fetch(%w(https://rubygems.org/ https://ruby-lang.org/ https://www.github.com/), HttpFetcher.new)
exit!
