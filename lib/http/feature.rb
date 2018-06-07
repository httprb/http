# frozen_string_literal: true

module HTTP
  class Feature
    def initialize(opts = {}) # rubocop:disable Style/OptionHash
      @opts = opts
    end

    def wrap_request(request)
      request
    end

    def wrap_response(response)
      response
    end
  end
end
