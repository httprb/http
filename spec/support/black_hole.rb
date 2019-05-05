# frozen_string_literal: true

module BlackHole
  class << self
    # rubocop:disable Style/MethodMissingSuper
    def method_missing(*)
      self
    end
    # rubocop:enable Style/MethodMissingSuper

    def respond_to_missing?(*)
      true
    end
  end
end
