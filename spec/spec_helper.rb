if RUBY_VERSION >= '1.9'
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]

  SimpleCov.start do
    add_filter '/spec/'
    minimum_coverage(80)
  end
end

require 'http'
require 'support/example_server'
require 'support/proxy_server'

# Allow testing against a SSL server
def certs_dir
  Pathname.new File.expand_path('../../tmp/certs', __FILE__)
end

require 'support/create_certs'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
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
