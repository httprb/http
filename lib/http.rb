require 'http/version'
require 'http/options'
require 'http/chainable'
require 'http/client'
require 'http/mime_type'
require 'http/parameters'
require 'http/response'
require 'http/event_callback'

# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/https'
require 'uri'

# Http, it can be simple!
module Http
  extend Chainable
end
