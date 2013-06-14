#!/usr/bin/env ruby
#
# Example of using the Http Gem with Celluloid::IO
# Make sure to 'gem install celluloid-io' before running
#
# Run as: bundle exec examples/celluloid.rb
#

require 'celluloid/io'
require 'http'

puts Http.get("https://www.google.com/", :socket_class => Celluloid::IO::TCPSocket, :ssl_socket_class => Celluloid::IO::SSLSocket)
