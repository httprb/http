require 'http/version'
require 'http/chainable'
require 'http/client'
require 'http/mime_type'
require 'http/parameters'
require 'http/response'


# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/https'
require 'uri'

# Http, it can be simple!
module Http
  extend Chainable
end

# TIMTOWTDI!
HTTP = Http
HttpClient = Http::Client
