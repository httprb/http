require 'http/version'
require 'http/chainable'
require 'http/client'
require 'http/headers'

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
