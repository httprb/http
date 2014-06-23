require 'base64'

module HTTP
  module AuthorizationHeader
    # OAuth2 Bearer token authorization header builder
    # @see http://tools.ietf.org/html/rfc6750
    class BearerToken
      # @param [#fetch] opts
      # @option opts [#to_s] :token
      # @option opts [#to_s] :encode (false)
      def initialize(opts)
        @encode = opts.fetch :encode, false
        @token  = opts.fetch :token
      end

      # Base64-encode the token if +@encode+ option is not false.
      # @return [String] Base64-encoded version of +@token+.
      def token
        return Base64.strict_encode64 @token if @encode
        @token
      end

      # :nodoc:
      def to_s
        "Bearer #{token}"
      end
    end

    register :bearer, BearerToken
  end
end
