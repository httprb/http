# frozen_string_literal: true

module HTTP
  module Features
    class Acceptable < Feature
      def wrap_response(response)
        return response if accepted?(response)

        Response.new(
          status:        406,
          version:       response.version,
          headers:       response.headers,
          proxy_headers: response.proxy_headers,
          connection:    response.connection,
          body:          response.body,
          request:       response.request
        )
      end

      private

      def accepted?(response)
        accept = response.request[Headers::ACCEPT]

        return true unless accept

        ranges = accept.split(/\s*,\s*/).map { |r| r.gsub(/\s*;.*/, "") }
        ranges.any? { |range| match?(response.mime_type, range) }
      end

      def match?(mime_type, range)
        return true if range == "*/*"

        m1, m2 = mime_type.split("/", 2)
        r1, r2 = range.split("/", 2)

        m1 == r1 && ["*", m2].include?(r2)
      end

      HTTP::Options.register_feature(:acceptable, self)
    end
  end
end
