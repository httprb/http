module BlackHole
  def method_missing(*); end
  module_function :method_missing
end
