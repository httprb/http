require 'http/version'
require 'http/options'
require 'http/chainable'
require 'http/client'
require 'http/mime_type'
require 'http/response'

# THIS IS ENTIRELY TEMPORARY, I ASSURE YOU
require 'net/https'
require 'uri'
require 'certified'

# Http, it can be simple!
module Http
  extend Chainable

  # Matches HTTP header names when in "Canonical-Http-Format"
  CANONICAL_HEADER = /^[A-Z][a-z]*(-[A-Z][a-z]*)*$/
end
