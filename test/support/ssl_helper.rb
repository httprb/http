# frozen_string_literal: true

require "openssl"
require "pathname"

module SSLHelper
  CERTS_PATH = Pathname.new File.expand_path("../../tmp/certs", __dir__)

  class << self
    def server_context
      context = OpenSSL::SSL::SSLContext.new

      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      context.key         = server_cert_key
      context.cert        = server_cert_cert
      context.ca_file     = ca_file

      context
    end

    def client_context
      # Ensure server cert is generated (triggers CA generation too)
      server_cert_cert
      context = OpenSSL::SSL::SSLContext.new

      context.options     = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      context.verify_hostname = true if context.respond_to?(:verify_hostname=)
      context.ca_file = ca_file

      context
    end

    def client_params
      server_cert_cert
      {
        ca_file: ca_file
      }
    end

    private

    def ca_key
      @ca_key ||= OpenSSL::PKey::RSA.new(2048)
    end

    def ca_cert
      @ca_cert ||= begin
        cert = OpenSSL::X509::Certificate.new
        cert.version    = 2
        cert.serial     = 1
        cert.subject    = OpenSSL::X509::Name.parse("/CN=honestachmed.com")
        cert.issuer     = cert.subject
        cert.public_key = ca_key.public_key
        cert.not_before = Time.now - 60
        cert.not_after  = Time.now + (365 * 24 * 60 * 60)

        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate  = cert

        cert.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
        cert.add_extension(ef.create_extension("keyUsage", "keyCertSign,cRLSign", true))

        cert.sign(ca_key, OpenSSL::Digest.new("SHA256"))
        cert
      end
    end

    def ca_file
      return @ca_file if defined?(@ca_file)

      CERTS_PATH.mkpath
      cert_file = CERTS_PATH.join("ca.crt")
      cert_file.open("w") { |io| io << ca_cert.to_pem }
      @ca_file = cert_file.to_s
    end

    def server_cert_key
      @server_cert_key ||= OpenSSL::PKey::RSA.new(2048)
    end

    def server_cert_cert
      @server_cert_cert ||= begin
        cert = OpenSSL::X509::Certificate.new
        cert.version    = 2
        cert.serial     = 2
        cert.subject    = OpenSSL::X509::Name.parse("/CN=127.0.0.1")
        cert.issuer     = ca_cert.subject
        cert.public_key = server_cert_key.public_key
        cert.not_before = Time.now - 60
        cert.not_after  = Time.now + (365 * 24 * 60 * 60)

        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate  = ca_cert

        cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
        cert.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
        cert.add_extension(ef.create_extension("extendedKeyUsage", "serverAuth"))
        cert.add_extension(ef.create_extension("subjectAltName", "IP:127.0.0.1"))

        cert.sign(ca_key, OpenSSL::Digest.new("SHA256"))
        cert
      end
    end
  end
end
