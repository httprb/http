require 'forwardable'
require 'singleton'

module HTTP
  module MimeType
    class Adapter
      include Singleton

      class << self
        extend Forwardable

        def_delegators :instance, :encode, :decode
      end
    end
  end
end
