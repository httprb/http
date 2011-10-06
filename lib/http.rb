require 'http/version'
require 'http/client'
require 'http/headers'

# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/https'
require 'uri'

# Http, it can be simple!
module Http
  def self.get(uri, options = {})
    Client.new(uri).get(options = {})
  end

  def self.with_headers(headers)
    Headers.new(headers)
  end
end

# TIMTOWTDI!
HTTP = Http
HttpClient = Http::Client
