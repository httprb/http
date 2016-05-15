# frozen_string_literal: true
module BlackHole
  def self.method_missing(*)
    self
  end
end
