# frozen_string_literal: true

require "digest"
require "securerandom"

module HTTP
  module Features
    # Implements HTTP Digest Authentication (RFC 2617 / RFC 7616)
    #
    # When a server responds with 401 and a Digest challenge, this feature
    # automatically computes the digest response and retries the request
    # with the correct Authorization header.
    class DigestAuth < Feature
      # Supported hash algorithms
      ALGORITHMS = {
        "MD5"          => Digest::MD5,
        "SHA-256"      => Digest::SHA256,
        "MD5-sess"     => Digest::MD5,
        "SHA-256-sess" => Digest::SHA256
      }.freeze

      # WWW-Authenticate header name
      # @api private
      WWW_AUTHENTICATE = "WWW-Authenticate"

      # Initialize the DigestAuth feature
      #
      # @example
      #   DigestAuth.new(user: "admin", pass: "secret")
      #
      # @param user [String] username for authentication
      # @param pass [String] password for authentication
      # @return [DigestAuth]
      # @api public
      def initialize(user:, pass:)
        @user = user
        @pass = pass
      end

      # Wraps the HTTP exchange to handle digest authentication challenges
      #
      # On a 401 with a Digest WWW-Authenticate header, flushes the error
      # response, computes digest credentials, and retries the request.
      #
      # @example
      #   feature.around_request(request) { |req| perform(req) }
      #
      # @param request [HTTP::Request]
      # @yield [HTTP::Request] the request to perform
      # @yieldreturn [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def around_request(request)
        response = yield request
        return response unless digest_challenge?(response)

        response.flush
        yield authorize(request, response)
      end

      private

      # Check if the response contains a digest authentication challenge
      #
      # @param response [HTTP::Response]
      # @return [Boolean]
      # @api private
      def digest_challenge?(response)
        www_auth = response.headers[WWW_AUTHENTICATE] #: String?
        response.status.code == 401 && www_auth&.start_with?("Digest ") == true
      end

      # Build an authorized copy of the request using the digest challenge
      #
      # @param request [HTTP::Request] the original request
      # @param response [HTTP::Response] the 401 response with challenge
      # @return [HTTP::Request] a new request with Authorization header
      # @api private
      def authorize(request, response)
        www_auth = response.headers[WWW_AUTHENTICATE] #: String
        challenge = parse_challenge(www_auth)
        headers   = request.headers.dup
        headers.set Headers::AUTHORIZATION, build_auth(request, challenge)

        Request.new(
          verb:           request.verb,
          uri:            request.uri,
          headers:        headers,
          proxy:          request.proxy,
          body:           request.body.source,
          version:        request.version,
          uri_normalizer: request.uri_normalizer
        )
      end

      # Parse the WWW-Authenticate header into a parameter hash
      #
      # @param header [String] the WWW-Authenticate header value
      # @return [Hash{String => String}] parsed challenge parameters
      # @api private
      def parse_challenge(header)
        params = {} #: Hash[String, String]
        header.sub(/\ADigest\s+/i, "").scan(/(\w+)=(?:"([^"]*)"|([\w-]+))/) do |match|
          key = match[0] #: String
          params[key] = format("%s", match[1] || match[2])
        end
        params
      end

      # Build the Authorization header value
      #
      # @param request [HTTP::Request] the request being authorized
      # @param challenge [Hash{String => String}] parsed challenge params
      # @return [String] the Digest authorization header value
      # @api private
      def build_auth(request, challenge)
        algorithm   = challenge.fetch("algorithm", "MD5")
        qop         = select_qop(challenge["qop"])
        nonce       = challenge.fetch("nonce")
        cnonce      = SecureRandom.hex(16)
        nonce_count = "00000001"
        uri         = String(request.uri.request_uri)
        ha1 = compute_ha1(algorithm, challenge.fetch("realm"), nonce, cnonce)
        ha2 = compute_ha2(algorithm, String(request.verb).upcase, uri)

        compute_auth_header(algorithm, qop, nonce, cnonce, nonce_count, uri, ha1, ha2, challenge)
      end

      # Compute digest and build the Authorization header string
      #
      # @return [String] formatted authorization header
      # @api private
      def compute_auth_header(algorithm, qop, nonce, cnonce, nonce_count, uri, ha1, ha2, challenge) # rubocop:disable Metrics/ParameterLists
        response = compute_response(algorithm, ha1, ha2, nonce: nonce,
                                    nonce_count: nonce_count, cnonce: cnonce, qop: qop)

        build_header(username: @user, realm: challenge.fetch("realm"), nonce: nonce, uri: uri,
                     qop: qop, nonce_count: nonce_count, cnonce: cnonce, response: response,
                     opaque: challenge["opaque"], algorithm: algorithm)
      end

      # Select the best qop value from the challenge
      #
      # @param qop_str [String, nil] comma-separated qop options
      # @return [String, nil] selected qop value
      # @api private
      def select_qop(qop_str)
        return unless qop_str

        qops = qop_str.split(",").map(&:strip)
        return "auth" if qops.include?("auth")

        qops.first
      end

      # Compute HA1 per RFC 2617
      #
      # @return [String] hex digest
      # @api private
      def compute_ha1(algorithm, realm, nonce, cnonce)
        base = hex_digest(algorithm, "#{@user}:#{realm}:#{@pass}")

        if algorithm.end_with?("-sess")
          hex_digest(algorithm, "#{base}:#{nonce}:#{cnonce}")
        else
          base
        end
      end

      # Compute HA2 per RFC 2617
      #
      # @return [String] hex digest
      # @api private
      def compute_ha2(algorithm, method, uri)
        hex_digest(algorithm, "#{method}:#{uri}")
      end

      # Compute the final digest response value
      #
      # @param algorithm [String] algorithm name
      # @param ha1 [String] HA1 hex digest
      # @param ha2 [String] HA2 hex digest
      # @param nonce [String] server nonce
      # @param nonce_count [String] request counter
      # @param cnonce [String] client nonce
      # @param qop [String, nil] quality of protection
      # @return [String] hex digest
      # @api private
      def compute_response(algorithm, ha1, ha2, nonce:, nonce_count:, cnonce:, qop:)
        if qop
          hex_digest(algorithm, "#{ha1}:#{nonce}:#{nonce_count}:#{cnonce}:#{qop}:#{ha2}")
        else
          hex_digest(algorithm, "#{ha1}:#{nonce}:#{ha2}")
        end
      end

      # Compute a hex digest using the specified algorithm
      #
      # @param algorithm [String] algorithm name
      # @param data [String] data to digest
      # @return [String] hex digest
      # @api private
      def hex_digest(algorithm, data)
        ALGORITHMS.fetch(algorithm.sub(/-sess\z/i, "")).hexdigest(data)
      end

      # Build the Digest Authorization header string
      #
      # @return [String] formatted header value
      # @api private
      def build_header(username:, realm:, nonce:, uri:, qop:, nonce_count:, cnonce:,
                       response:, opaque:, algorithm:)
        parts = [
          %(username="#{username}"),
          %(realm="#{realm}"),
          %(nonce="#{nonce}"),
          %(uri="#{uri}")
        ]

        parts.push(%(qop=#{qop}), %(nc=#{nonce_count}), %(cnonce="#{cnonce}")) if qop

        parts << %(response="#{response}")
        parts << %(opaque="#{opaque}") if opaque
        parts << %(algorithm=#{algorithm})

        "Digest #{parts.join(', ')}"
      end

      HTTP::Options.register_feature(:digest_auth, self)
    end
  end
end
