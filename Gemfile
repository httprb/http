# frozen_string_literal: true

source "https://rubygems.org"
ruby RUBY_VERSION

gem "rake"

# Ruby 3.0 does not ship it anymore.
# TODO: We should probably refactor tests to avoid need for it.
gem "webrick"

group :development do
  gem "debug", platform: :mri

  gem "nokogiri", require: false
end

group :test do
  gem "certificate_authority", "~> 1.0", require: false
  gem "logger"

  gem "backports"

  gem "rubocop",             "~> 1.85"
  gem "rubocop-minitest",    "~> 0.36"
  gem "rubocop-performance", "~> 1.26"
  gem "rubocop-rake",        "~> 0.7.1"

  gem "simplecov",      require: false
  gem "simplecov-lcov", require: false

  gem "minitest"
  gem "minitest-memory"
  gem "minitest-mock"

  gem "yardstick"
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
