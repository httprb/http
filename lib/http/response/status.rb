require 'delegate'

module HTTP
  class Response
    class Status < ::Delegator
      REASONS = {
        100 => 'Continue',
        101 => 'Switching Protocols',
        102 => 'Processing',
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        207 => 'Multi-Status',
        226 => 'IM Used',
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        306 => 'Reserved',
        307 => 'Temporary Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Long',
        415 => 'Unsupported Media Type',
        416 => 'Requested Range Not Satisfiable',
        417 => 'Expectation Failed',
        418 => "I'm a Teapot",
        422 => 'Unprocessable Entity',
        423 => 'Locked',
        424 => 'Failed Dependency',
        426 => 'Upgrade Required',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported',
        506 => 'Variant Also Negotiates',
        507 => 'Insufficient Storage',
        510 => 'Not Extended'
      }.freeze

      # Status code
      #
      # @return [Fixnum]
      attr_reader :code

      if RUBY_VERSION < '1.9.0'
        # @param [#to_i] code
        def initialize(code)
          super __setobj__ code
        end
      end

      # Status message
      #
      # @return [String]
      def reason
        REASONS[code]
      end

      # Printable version of HTTP Status, surrounded by quote marks,
      # with special characters escaped.
      #
      # (see String#inspect)
      def inspect
        "#{code} #{reason}".inspect
      end

      REASONS.each do |code, reason|
        # "Bad Request"   => "bad_request"
        # "I'm a Teapot"  => "im_a_teapot"
        helper_name = reason.downcase.gsub(/[^a-z ]+/, ' ').gsub(/ +/, '_')

        class_eval <<-RUBY, __FILE__, __LINE__
          def #{helper_name}? # def bad_request?
            #{code} == code   #   400 == code
          end                 # end
        RUBY
      end

      def __setobj__(obj)
        @code = obj.to_i
      end

      def __getobj__
        @code
      end
    end
  end
end
