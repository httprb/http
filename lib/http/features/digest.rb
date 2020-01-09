# frozen_string_literal: true

require "net/http/digest_auth"

module HTTP
  module Features
    class Digest < Feature
      def wrap_response(response)
        if response.status.code == 401
          digest = Net::HTTP::DigestAuth.new
          auth = digest.auth_header(response.request.uri, response["WWW-Authenticate"], response.request.verb.to_s.upcase)
          response = HTTP.auth(auth).get(response.request.uri)
        end
        response
      end

      HTTP::Options.register_feature(:digest, self)
    end
  end
end
