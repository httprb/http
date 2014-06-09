require 'rspec/its'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage(80)
end

require 'http'
require 'support/example_server'
require 'support/proxy_server'

RSpec.configure do |config|
  config.disable_monkey_patching!
end

def capture_warning
  begin
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    result = $stderr.string
  ensure
    $stderr = old_stderr
  end
  result
end
