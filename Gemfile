source "https://rubygems.org"

gem "jruby-openssl" if defined? JRUBY_VERSION
gem "rake"

gem "rack-cache", "~> 1.2"

group :development do
  gem "celluloid-io"
  gem "guard"
  gem "guard-rspec", :require => false
  gem "nokogiri", :require => false
  gem "pry"

  platforms :ruby_19, :ruby_20 do
    gem "pry-debugger"
    gem "pry-stack_explorer"
  end
end

group :test do
  gem "backports"
  gem "coveralls"
  gem "simplecov",    ">= 0.9"
  gem "json",         ">= 1.8.1"
  gem "mime-types",   "~> 1.25",  :platforms => [:jruby]
  gem "rest-client",  "~> 1.6.0", :platforms => [:jruby]
  gem "rspec",        "~> 3.2.0"
  gem "rspec-its"
  gem "rubocop",      "~> 0.31.0"
  gem "yardstick"
  gem "certificate_authority"
end

group :doc do
  gem "redcarpet"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
