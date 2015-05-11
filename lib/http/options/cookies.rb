module HTTP
  class Options
    # Default path of cookies
    DEFAULT_COOKIE_PATH = "/".freeze

    def_option :cookies do |cookies|
      cookies.each_with_object self.cookies.dup do |(k, v), jar|
        cookie = case
                 when k.is_a?(Cookie) then k
                 when k.is_a?(Hash)   then Cookie.new k
                 when v.is_a?(Hash)   then Cookie.new(k.to_s, v)
                 else                      Cookie.new(k.to_s, v.to_s)
                 end

        cookie.path ||= DEFAULT_COOKIE_PATH
        jar[cookie.name] = cookie.set_cookie_value
      end
    end
  end
end
