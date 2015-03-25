module BlackHole
  def self.method_missing(*)
    self
  end
end
