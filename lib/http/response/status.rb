# frozen_string_literal: true

require "delegate"

require "http/response/status/reasons"

module HTTP
  class Response
    # Represents an HTTP response status code with reason phrase
    class Status < ::Delegator
      class << self
        # Coerces given value to Status
        #
        # @example
        #   Status.coerce(:bad_request) # => Status.new(400)
        #
        # @raise [Error] if coercion is impossible
        # @param [Symbol, #to_i] object
        # @return [Status]
        # @api public
        def coerce(object)
          code = case object
                 when String  then SYMBOL_CODES.fetch(symbolize(object), nil)
                 when Symbol  then SYMBOL_CODES.fetch(object, nil)
                 when Numeric then object
                 end

          return new code if code

          raise Error, "Can't coerce #{object.class}(#{object}) to #{self}"
        end
        alias [] coerce

        private

        # Symbolizes given string
        #
        # @param [#to_s] str
        # @return [Symbol]
        # @api private
        def symbolize(str)
          str.downcase.tr("- ", "_").to_sym
        end
      end

      # Code to Symbol map
      #
      # @example Usage
      #
      #   SYMBOLS[400] # => :bad_request
      #   SYMBOLS[414] # => :request_uri_too_long
      #   SYMBOLS[418] # => :im_a_teapot
      #
      # @return [Hash<Fixnum => Symbol>]
      SYMBOLS = REASONS.transform_values { |v| symbolize(v) }.freeze

      # Reversed {SYMBOLS} map.
      #
      # @example Usage
      #
      #   SYMBOL_CODES[:bad_request]           # => 400
      #   SYMBOL_CODES[:request_uri_too_long]  # => 414
      #   SYMBOL_CODES[:im_a_teapot]           # => 418
      #
      # @return [Hash<Symbol => Fixnum>]
      SYMBOL_CODES = SYMBOLS.to_h { |k, v| [v, k] }.freeze

      # The numeric status code
      #
      # @example
      #   status.code # => 200
      #
      # @return [Fixnum] status code
      # @api public
      attr_reader :code

      # Return the reason phrase for the status code
      #
      # @example
      #   status.reason # => "OK"
      #
      # @see REASONS
      # @return [String, nil] status message
      # @api public
      def reason
        REASONS[code]
      end

      # Return string representation of HTTP status
      #
      # @example
      #   status.to_s # => "200 OK"
      #
      # @return [String]
      # @api public
      def to_s
        reason ? "#{code} #{reason}" : code.to_s
      end

      # Check if status code is informational (1XX)
      #
      # @example
      #   status.informational? # => false
      #
      # @return [Boolean]
      # @api public
      def informational?
        100 <= code && code < 200
      end

      # Check if status code is successful (2XX)
      #
      # @example
      #   status.success? # => true
      #
      # @return [Boolean]
      # @api public
      def success?
        200 <= code && code < 300
      end

      # Check if status code is redirection (3XX)
      #
      # @example
      #   status.redirect? # => false
      #
      # @return [Boolean]
      # @api public
      def redirect?
        300 <= code && code < 400
      end

      # Check if status code is client error (4XX)
      #
      # @example
      #   status.client_error? # => false
      #
      # @return [Boolean]
      # @api public
      def client_error?
        400 <= code && code < 500
      end

      # Check if status code is server error (5XX)
      #
      # @example
      #   status.server_error? # => false
      #
      # @return [Boolean]
      # @api public
      def server_error?
        500 <= code && code < 600
      end

      # Symbolized {#reason}
      #
      # @example
      #   status.to_sym # => :ok
      #
      # @return [nil] unless code is well-known (see REASONS)
      # @return [Symbol]
      # @api public
      def to_sym
        SYMBOLS[code]
      end

      # Printable version of HTTP Status
      #
      # @example
      #   status.inspect # => "#<HTTP::Response::Status 200 OK>"
      #
      # (see String#inspect)
      # @return [String]
      # @api public
      def inspect
        "#<#{self.class} #{self}>"
      end

      SYMBOLS.each do |code, symbol|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{symbol}?      # def bad_request?
            #{code} == code   #   400 == code
          end                 # end
        RUBY
      end

      # Set the delegate object
      #
      # @example
      #   status.__setobj__(200)
      #
      # @return [void]
      # @api public
      def __setobj__(obj)
        raise TypeError, "Expected #{obj.inspect} to respond to #to_i" unless obj.respond_to? :to_i

        @code = obj.to_i
      end

      # Return the delegate object
      #
      # @example
      #   status.__getobj__ # => 200
      #
      # @return [Fixnum]
      # @api public
      def __getobj__
        @code
      end
    end
  end
end
