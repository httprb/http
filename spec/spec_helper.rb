require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage(88.25)
end

require 'http'
require 'support/example_server'
require 'support/proxy_server'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def capture_warning(&block)
  begin
    old_stderr = $stderr
    $stderr = StringIO.new
    block.call
    result = $stderr.string
  ensure
    $stderr = old_stderr
  end
  result
end
