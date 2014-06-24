require 'base64'

module HTTP
  module AuthorizationHeader
    # OAuth2 Bearer token authorization header builder
    # @see http://tools.ietf.org/html/rfc6750
    #
    # @deprecated Will be remove in v0.7.0
    class BearerToken
      # @param [#fetch] opts
      # @option opts [#to_s] :token
      # @option opts [Boolean] :encode (false) deprecated
      def initialize(opts)
        warn "#{Kernel.caller.first}: [DEPRECATION] BearerToken deprecated."

        @token = opts.fetch :token
        @token = Base64.strict_encode64 @token if opts.fetch(:encode, false)
      end

      # :nodoc:
      def to_s
        "Bearer #{@token}"
      end
    end

    register :bearer, BearerToken
  end
end
