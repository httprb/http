# frozen_string_literal: true
module HTTP
  # Printer for {HTTP::Request} and {HTTP::Response}.
  # Expects `headline` method to be implemented.
  #
  # @example Usage
  #
  #   class MyHttpRequest
  #     include HTTP::PrettyPrinter
  #
  #     def headline
  #       "MyHttpRequest headline"
  #     end
  #   end
  module PrettyPrinter
    # Returns human-readable representation including headers.
    #
    # @return [String]
    def inspect
      pretty_print(:skip_headers => false)
    end

    # Returns a printable representation of headers.
    # @option [Hash] options
    #   @param [Boolean] skip_headers
    #   @param [Boolean] skip_body
    #   @param [String] separator
    # @return [String]
    def pretty_print(skip_headers: true, skip_body: true, separator: "\n")
      StringIO.open do |io|
        io << headline
        append_headers(io, separator) unless skip_headers
        io << "#{separator}#{body}" unless skip_body || skip_headers
        io.string
      end
    end

    private

    def append_headers(io, separator)
      headers.group_by { |header| header[0] }.each do |name, values|
        value = values.map { |item| item.last }.join("; ")
        io << "#{separator}#{name}: #{value}"
      end
    end

    def headline
      raise NotImplementedError, "'headline' method must be implemented by classes/modules that include HTTP::PrettyPrinter module"
    end
  end
end
