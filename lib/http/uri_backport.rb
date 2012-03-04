# Taken from Ruby 1.9's uri/common.rb
# By Akira Yamada <akira@ruby-lang.org>
# License:
#   You can redistribute it and/or modify it under the same term as Ruby.

require 'uri'

# Backport Ruby 1.9's form encoding/decoding functionality
module URI
  TBLENCWWWCOMP_ = {} # :nodoc:
  256.times do |i|
    TBLENCWWWCOMP_[i.chr] = '%%%02X' % i
  end
  TBLENCWWWCOMP_[' '] = '+'
  TBLENCWWWCOMP_.freeze
  TBLDECWWWCOMP_ = {} # :nodoc:
  256.times do |i|
    h, l = i>>4, i&15
    TBLDECWWWCOMP_['%%%X%X' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%x%X' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%X%x' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%x%x' % [h, l]] = i.chr
  end
  TBLDECWWWCOMP_['+'] = ' '
  TBLDECWWWCOMP_.freeze

  # Encode given +str+ to URL-encoded form data.
  #
  # This method doesn't convert *, -, ., 0-9, A-Z, _, a-z, but does convert SP
  # (ASCII space) to + and converts others to %XX.
  #
  # This is an implementation of
  # http://www.w3.org/TR/html5/association-of-controls-and-forms.html#url-encoded-form-data
  #
  # See URI.decode_www_form_component, URI.encode_www_form
  def self.encode_www_form_component(str)
    str.to_s.gsub(/[^*\-.0-9A-Z_a-z]/) { |chr| TBLENCWWWCOMP_[chr] }
  end

  # Decode given +str+ of URL-encoded form data.
  #
  # This decods + to SP.
  #
  # See URI.encode_www_form_component, URI.decode_www_form
  def self.decode_www_form_component(str)
    raise ArgumentError, "invalid %-encoding (#{str})" unless /\A[^%]*(?:%\h\h[^%]*)*\z/ =~ str
    str.gsub(/\+|%\h\h/) { |chr| TBLDECWWWCOMP_[chr] }
  end

  # Generate URL-encoded form data from given +enum+.
  #
  # This generates application/x-www-form-urlencoded data defined in HTML5
  # from given an Enumerable object.
  #
  # This internally uses URI.encode_www_form_component(str).
  #
  # This method doesn't convert the encoding of given items, so convert them
  # before call this method if you want to send data as other than original
  # encoding or mixed encoding data. (Strings which are encoded in an HTML5
  # ASCII incompatible encoding are converted to UTF-8.)
  #
  # This method doesn't handle files.  When you send a file, use
  # multipart/form-data.
  #
  # This is an implementation of
  # http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
  #
  #    URI.encode_www_form([["q", "ruby"], ["lang", "en"]])
  #    #=> "q=ruby&lang=en"
  #    URI.encode_www_form("q" => "ruby", "lang" => "en")
  #    #=> "q=ruby&lang=en"
  #    URI.encode_www_form("q" => ["ruby", "perl"], "lang" => "en")
  #    #=> "q=ruby&q=perl&lang=en"
  #    URI.encode_www_form([["q", "ruby"], ["q", "perl"], ["lang", "en"]])
  #    #=> "q=ruby&q=perl&lang=en"
  #
  # See URI.encode_www_form_component, URI.decode_www_form
  def self.encode_www_form(enum)
    enum.map do |k,v|
      if v.nil?
        encode_www_form_component(k)
      elsif v.respond_to?(:to_ary)
        v.to_ary.map do |w|
          str = encode_www_form_component(k)
          unless w.nil?
            str << '='
            str << encode_www_form_component(w)
          end
        end.join('&')
      else
        str = encode_www_form_component(k)
        str << '='
        str << encode_www_form_component(v)
      end
    end.join('&')
  end

  WFKV_ = '(?:[^%#=;&]*(?:%\h\h[^%#=;&]*)*)' # :nodoc:

  # Decode URL-encoded form data from given +str+.
  #
  # This decodes application/x-www-form-urlencoded data
  # and returns array of key-value array.
  # This internally uses URI.decode_www_form_component.
  #
  # _charset_ hack is not supported now because the mapping from given charset
  # to Ruby's encoding is not clear yet.
  # see also http://www.w3.org/TR/html5/syntax.html#character-encodings-0
  #
  # This refers http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
  #
  # ary = URI.decode_www_form("a=1&a=2&b=3")
  # p ary                  #=> [['a', '1'], ['a', '2'], ['b', '3']]
  # p ary.assoc('a').last  #=> '1'
  # p ary.assoc('b').last  #=> '3'
  # p ary.rassoc('a').last #=> '2'
  # p Hash[ary]            # => {"a"=>"2", "b"=>"3"}
  #
  # See URI.decode_www_form_component, URI.encode_www_form
  def self.decode_www_form(str)
    return [] if str.empty?
    unless /\A#{WFKV_}=#{WFKV_}(?:[;&]#{WFKV_}=#{WFKV_})*\z/o =~ str
      raise ArgumentError, "invalid data of application/x-www-form-urlencoded (#{str})"
    end
    ary = []
    $&.scan(/([^=;&]+)=([^;&]*)/) do
      ary << [decode_www_form_component($1), decode_www_form_component($2)]
    end
    ary
  end
end
