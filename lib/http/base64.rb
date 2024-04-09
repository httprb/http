# frozen_string_literal: true

module HTTP
  module Base64
    module_function

    # Equivalent to Base64.strict_encode64
    def encode64(input)
      [input].pack("m0")
    end
  end
end
