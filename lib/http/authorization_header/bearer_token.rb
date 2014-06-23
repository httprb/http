require 'base64'

module HTTP
  module AuthorizationHeader
    # OAuth2 Bearer token authorization header builder
    # @see http://tools.ietf.org/html/rfc6750
    class BearerToken
      # @param [#fetch] opts
      # @option opts [#to_s] :token
      # @option opts [Boolean] :encode (false) deprecated
      def initialize(opts)
        @token = opts.fetch :token

        return unless opts.fetch(:encode, false)

        warn "#{Kernel.caller.first}: [DEPRECATION] BearerToken :encode option is deprecated. " \
          "You should pass encoded token on your own: { :token => Base64.strict_encode64('token') }"
        @token = Base64.strict_encode64 @token
      end

      # :nodoc:
      def to_s
        "Bearer #{@token}"
      end
    end

    register :bearer, BearerToken
  end
end
