require 'http/version'
require 'http/client'
require 'http/headers'

# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/https'
require 'uri'

# Http, it can be simple!
module Http
  class << self
    def get(uri, options = {})
      Client.new(uri).get(options = {})
    end

    def with_headers(headers)
      Headers.new(headers)
    end
    alias_method :with, :with_headers
  end
end

# TIMTOWTDI!
HTTP = Http
HttpClient = Http::Client
