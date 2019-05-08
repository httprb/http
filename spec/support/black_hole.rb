# frozen_string_literal: true

module BlackHole
  class << self
    def method_missing(*) # rubocop:disable Style/MethodMissingSuper
      self
    end

    def respond_to_missing?(*)
      true
    end
  end
end
