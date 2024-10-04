# frozen_string_literal: true

module HTTP
  module Features
    class RaiseError < Feature
      def initialize(ignore: [])
        super()

        @ignore = ignore
      end

      def wrap_response(response)
        if response.code >= 400 && !@ignore.include?(response.code)
          raise HTTP::StatusError, "Unexpected status code #{response.code}"
        end

        response
      end

      HTTP::Options.register_feature(:raise_error, self)
    end
  end
end
