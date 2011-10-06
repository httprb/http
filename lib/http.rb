require 'http/version'
require 'http/client'

# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/http'
require 'uri'

# Http, it can be simple!
module Http
  def self.get(uri, options = {})
    Client.new(uri).get(options = {})
  end
end

# TIMTOWTDI!
HTTP = Http
HttpClient = Http::Client