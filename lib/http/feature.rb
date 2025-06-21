# frozen_string_literal: true

module HTTP
  class Feature
    def wrap_request(request)
      request
    end

    def wrap_response(response)
      response
    end

    def on_error(_request, _error); end
  end
end

require "http/features/acceptable"
require "http/features/auto_inflate"
require "http/features/auto_deflate"
require "http/features/instrumentation"
require "http/features/logging"
require "http/features/normalize_uri"
require "http/features/raise_error"
