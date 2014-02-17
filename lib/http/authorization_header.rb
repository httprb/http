module HTTP
  # Authorization header value builders
  module AuthorizationHeader
    class << self
      # Associate type with given builder.
      # @param [#to_sym] type
      # @param [Class] klass
      # @return [void]
      def register(type, klass)
        builders[type.to_sym] = klass
      end

      # Builds Authorization header value with associated builder.
      # @param [#to_sym] type
      # @param [Object] opts
      # @return [String]
      def build(type, opts)
        klass = builders[type.to_sym]

        fail Error, "Unknown authorization type #{type}" unless klass

        klass.new opts
      end

    private

      # :nodoc:
      def builders
        @builders ||= {}
      end
    end
  end
end

# built-in builders
require 'http/authorization_header/basic_auth'
require 'http/authorization_header/bearer_token'
