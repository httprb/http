# frozen_string_literal: true

module HTTP
  class Request
    class Proxy
      def initialize(proxy_params, request_uri)
        @proxy = proxy_params || find_proxy(request_uri)
      end

      # @return [Boolean] Is there any proxy configuration available?
      def available?
        @proxy && @proxy.include?(:proxy_address) && @proxy.include?(:proxy_port)
      end

      # @return [Boolean] Does the proxy include authentication credentials?
      def authenticated?
        @proxy && @proxy.include?(:proxy_username) && @proxy.include?(:proxy_password)
      end

      # @return [Boolean] Does the proxy include additional request headers?
      def include_headers?
        @proxy.key?(:proxy_headers)
      end

      # @return [String, nil] Username (authentication credential)
      def username
        @proxy[:proxy_username]
      end

      # @return [String, nil] Password (authentication credential)
      def password
        @proxy[:proxy_password]
      end

      # @return [String, nil] Address
      def address
        @proxy[:proxy_address]
      end

      # @return [String, Integer, nil] Port
      def port
        @proxy[:proxy_port]
      end

      # @return [Hash, nil] Additional headers
      def headers
        @proxy[:proxy_headers]
      end

      private

      def find_proxy(request_uri)
        system_proxy = find_system_proxy(request_uri)

        proxy = {}
        proxy[:proxy_username] = system_proxy.user if system_proxy&.user
        proxy[:proxy_password] = system_proxy.password if system_proxy&.password
        proxy[:proxy_address] = system_proxy.host if system_proxy&.host
        proxy[:proxy_port] = system_proxy.port if system_proxy&.port

        proxy
      end

      def find_system_proxy(request_uri)
        ::URI.parse(request_uri.to_s).find_proxy
      end
    end
  end
end
