# frozen_string_literal: true

require "pathname"

require "certificate_authority"

module SSLHelper
  CERTS_PATH = Pathname.new File.expand_path("../../tmp/certs", __dir__)
  CA_EXTENSIONS = {
    "basicConstraints" => { "ca" => true, "critical" => true },
    "keyUsage"         => { "usage" => %w[critical keyCertSign cRLSign] },
    "extendedKeyUsage" => { "usage" => [] }
  }.freeze
  SERVER_EXTENSIONS = {
    "basicConstraints" => { "ca" => false },
    "keyUsage"         => { "usage" => %w[critical digitalSignature keyEncipherment] },
    "extendedKeyUsage" => { "usage" => ["serverAuth"] },
    "subjectAltName"   => { "ips" => ["127.0.0.1"] }
  }.freeze

  class RootCertificate < ::CertificateAuthority::Certificate
    def initialize
      super

      subject.common_name  = "honestachmed.com"
      serial_number.number = 1
      key_material.generate_key

      self.signing_entity = true

      sign!("extensions" => CA_EXTENSIONS)
    end

    def file
      return @file if defined? @file

      CERTS_PATH.mkpath

      cert_file = CERTS_PATH.join("ca.crt")
      cert_file.open("w") { |io| io << to_pem }

      @file = cert_file.to_s
    end
  end

  class ChildCertificate < ::CertificateAuthority::Certificate
    def initialize(parent, common_name:, serial_number:, extensions:)
      super()

      subject.common_name = common_name
      self.serial_number.number = serial_number

      key_material.generate_key

      self.parent = parent

      sign!("extensions" => extensions)
    end

    def cert
      OpenSSL::X509::Certificate.new to_pem
    end

    def key
      OpenSSL::PKey::RSA.new key_material.private_key.to_pem
    end
  end

  class << self
    def server_context
      context = OpenSSL::SSL::SSLContext.new

      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      context.key         = server_cert.key
      context.cert        = server_cert.cert
      context.ca_file     = ca.file

      context
    end

    def client_context
      server_cert
      context = OpenSSL::SSL::SSLContext.new

      context.options     = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      context.verify_hostname = true if context.respond_to?(:verify_hostname=)
      context.ca_file = ca.file

      context
    end

    def client_params
      server_cert
      {
        ca_file: ca.file
      }
    end

    def server_cert
      @server_cert ||= ChildCertificate.new(
        ca,
        common_name:   "127.0.0.1",
        serial_number: 2,
        extensions:    SERVER_EXTENSIONS
      )
    end

    def ca
      @ca ||= RootCertificate.new
    end
  end
end
