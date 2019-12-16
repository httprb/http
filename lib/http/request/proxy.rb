# frozen_string_literal: true

module HTTP
  class Request
    class Proxy
      # Try to find proxy attributes set via ENV variables matching against request_uri
      # @see ::URI::Generic#find_proxy
      # @param [HTTP::URI] request_uri
      # @return [HTTP::Request::Proxy]
      def self.auto_detect(request_uri)
        system_proxy = ::URI.parse(request_uri.to_s).find_proxy

        proxy = {}
        proxy[:proxy_username] = system_proxy.user if system_proxy&.user
        proxy[:proxy_password] = system_proxy.password if system_proxy&.password
        proxy[:proxy_address] = system_proxy.host if system_proxy&.host
        proxy[:proxy_port] = system_proxy.port if system_proxy&.port

        new(proxy)
      end

      def initialize(proxy_params)
        @proxy = proxy_params || {}
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
    end
  end
end
