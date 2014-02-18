require 'base64'

module HTTP
  module AuthorizationHeader
    # Basic authorization header builder
    # @see http://tools.ietf.org/html/rfc2617
    class BasicAuth
      # @param [#fetch] opts
      # @option opts [#to_s] :user
      # @option opts [#to_s] :pass
      def initialize(opts)
        @user = opts.fetch :user
        @pass = opts.fetch :pass
      end

      # :nodoc:
      def to_s
        'Basic ' << Base64.strict_encode64("#{@user}:#{@pass}")
      end
    end

    register :basic, BasicAuth
  end
end
