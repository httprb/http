module Base64
  # :nodoc:
  def self.strict_encode64(data)
    encode64(data).gsub(/\n/, '')
  end
end
