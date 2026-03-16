# frozen_string_literal: true

source "https://rubygems.org"
ruby RUBY_VERSION

gem "rake"

group :development do
  gem "debug", platform: :mri

  gem "nokogiri", require: false
end

group :test do
  gem "addressable", "~> 2.8"
  gem "logger"

  gem "rubocop",             "~> 1.85"
  gem "rubocop-minitest",    "~> 0.36"
  gem "rubocop-performance", "~> 1.26"
  gem "rubocop-rake",        "~> 0.7.1"

  gem "simplecov",      require: false
  gem "simplecov-lcov", require: false

  gem "minitest-memory", platform: :mri
  gem "minitest-mock"
  gem "minitest-strict"

  gem "mutant-minitest"

  gem "yardstick"
end

group :sig do
  gem "steep"
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
