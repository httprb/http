source "https://rubygems.org"

gem "rake"

group :development do
  gem "guard-rspec", :require => false
  gem "nokogiri",    :require => false
  gem "pry",         :require => false

  platform :ruby_20 do
    gem "pry-debugger",       :require => false
    gem "pry-stack_explorer", :require => false
  end
end

group :test do
  gem "backports"
  gem "coveralls", :require => false
  gem "simplecov", ">= 0.9"
  gem "json",      ">= 1.8.1"
  gem "rubocop",   "=  0.40.0"
  gem "rspec",     "~> 3.0"
  gem "rspec-its"
  gem "yardstick"
  gem "certificate_authority", :require => false
  gem "activemodel", "~> 4", :require => false # Used by certificate_authority
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
