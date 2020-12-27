# frozen_string_literal: true

source "https://rubygems.org"
ruby RUBY_VERSION

gem "rake"

gem "openssl", "~> 2.0.7", :platform => :jruby

group :development do
  gem "guard-rspec", :require => false
  gem "nokogiri",    :require => false
  gem "pry",         :require => false

  # RSpec formatter
  gem "fuubar", :require => false

  platform :mri do
    gem "pry-byebug"
  end
end

group :test do
  gem "certificate_authority", "~> 1.0", :require => false

  gem "backports"

  gem "simplecov",      :require => false
  gem "simplecov-lcov", :require => false

  gem "rspec", "~> 3.10"
  gem "rspec-its"

  gem "rubocop", "= 0.68.1"
  gem "rubocop-performance"

  gem "yardstick"
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
