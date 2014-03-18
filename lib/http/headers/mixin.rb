require 'forwardable'

module HTTP
  class Headers
    module Mixin
      extend Forwardable
      attr_reader :headers
      def_delegators :headers, :[], :[]=
    end
  end
end
