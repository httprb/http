module ServerConfig
  def ssl?
    !!config[:SSLEnable]
  end

  def addr
    config[:BindAddress]
  end

  def port
    config[:Port]
  end
end
