# frozen_string_literal: true

require "ipaddr"
require "socket"

module HTTP
  # Denies requests to hostnames and IP addresses matching configured rules
  #
  # @example
  #   HTTP::Blocklist.new([IPAddr.new("127.0.0.0/8"), "internal.example.com"])
  #   HTTP::Blocklist.new(deny: ->(address) { address.loopback? || address.private? })
  class Blocklist
    # Returns existing Blocklist or creates a new one
    #
    # @example
    #   HTTP::Blocklist.new([IPAddr.new("127.0.0.0/8"), "localhost"])
    #
    # @param [HTTP::Blocklist, Array<IPAddr, String>, String] entries
    # @param [#call, nil] deny predicate called with each resolved address
    # @return [HTTP::Blocklist]
    # @api public
    def self.new(entries = [], deny: nil)
      return entries if entries.is_a?(Blocklist)

      super
    end

    # Initializes a blocklist from address rules, hostname rules, and a predicate
    #
    # @example
    #   HTTP::Blocklist.new([IPAddr.new("169.254.0.0/16")], deny: ->(ip) { ip.loopback? })
    #
    # @param [Array<IPAddr, String>, String] entries address and hostname rules
    # @param [#call, nil] deny called with each resolved address, truthy blocks it
    # @return [HTTP::Blocklist]
    # @api public
    def initialize(entries, deny:)
      rules = Array(entries) #: Array[IPAddr | String]
      hosts = rules.grep(String) #: Array[String]

      @addresses = rules.grep(IPAddr)
      @hosts     = hosts.map { |entry| ".#{normalize_host(entry)}" }
      @deny      = deny
    end

    # Whether a hostname matches any hostname rule
    #
    # @example
    #   blocklist.blocked_host?("api.example.com")
    #
    # @param [String] host hostname to check
    # @return [Boolean]
    # @api public
    def blocked_host?(host)
      name = ".#{normalize_host(host)}"
      @hosts.any? { |rule| name.end_with?(rule) }
    end

    # Whether an address matches any address rule or is denied by the predicate
    #
    # IPv4-mapped IPv6 addresses are reduced to their native IPv4 form first,
    # so `::ffff:127.0.0.1` cannot slip past a `127.0.0.0/8` rule, and `deny`
    # sees the same normalized address.
    #
    # @example
    #   blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
    #
    # @param [IPAddr] address address to check
    # @return [Boolean]
    # @api public
    def blocked_address?(address)
      ip   = address.native
      deny = @deny

      return true if @addresses.any? { |rule| rule.include?(ip) }
      return false unless deny

      deny.call(ip) ? true : false
    end

    # Resolves a hostname, denying it if the name or any address is blocked
    #
    # Hostname rules are checked before resolving, so a blocked name never
    # generates DNS traffic. Every resolved address is checked, and the first
    # one is returned so the caller can connect to a validated address rather
    # than resolving a second time.
    #
    # @example
    #   blocklist.validate!("example.com") # => "93.184.216.34"
    #
    # @param [String] host hostname or IP address to resolve
    # @return [String] the validated address to connect to
    # @raise [HTTP::BlockedHostError] when the host or an address is blocked
    # @api public
    def validate!(host)
      raise BlockedHostError, "blocked host: #{host}" if blocked_host?(host)

      addresses = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)

      addresses.each do |address|
        next unless blocked_address?(IPAddr.new(address))

        raise BlockedHostError, "#{host} resolves to blocked address: #{address}"
      end

      addresses.first
    end

    # Warns once that a blocklist cannot be enforced through a proxy
    #
    # @example
    #   blocklist.warn_proxy_incompatible
    #
    # @return [void]
    # @api private
    def warn_proxy_incompatible
      return if @warned

      @warned = true
      warn "HTTP::Blocklist: a blocklist cannot be enforced through a proxy, because the proxy " \
           "resolves the target and makes the connection; the addresses checked here are not " \
           "necessarily the ones reached"
    end

    private

    # Normalizes a hostname for comparison
    #
    # @param [String] host hostname to normalize
    # @return [String] downcased hostname without a trailing dot
    # @api private
    def normalize_host(host)
      host.downcase.chomp(".")
    end
  end
end
