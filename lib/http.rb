require 'http/parser'

require 'http/errors'
require 'http/chainable'
require 'http/client'
require 'http/options'
require 'http/request'
require 'http/request/writer'
require 'http/response'
require 'http/response/body'
require 'http/response/parser'
require 'http/backports'

# HTTP should be easy
module HTTP
  extend Chainable

  class << self
    # HTTP[:accept => 'text/html'].get(...)
    alias_method :[], :with_headers
  end
end

Http = HTTP unless defined?(Http)
