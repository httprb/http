require 'http'
require 'support/example_server'
require 'support/proxy_server'
require 'coveralls'
Coveralls.wear!

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
