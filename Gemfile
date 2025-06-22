# frozen_string_literal: true

source "https://rubygems.org"
ruby RUBY_VERSION

gem "rake"

# Ruby 3.0 does not ship it anymore.
# TODO: We should probably refactor specs to avoid need for it.
gem "webrick"

group :development do
  gem "debug", platform: :mri

  gem "guard-rspec", require: false
  gem "nokogiri",    require: false

  # RSpec formatter
  gem "fuubar", require: false
end

group :test do
  gem "certificate_authority", "~> 1.0", require: false

  gem "backports"

  gem "rubocop",             "~> 1.76.0"
  gem "rubocop-performance", "~> 1.25.0"
  gem "rubocop-rake",        "~> 0.7.1"
  gem "rubocop-rspec",       "~> 3.6.0"

  gem "simplecov",      require: false
  gem "simplecov-lcov", require: false

  gem "rspec", "~> 3.10"
  gem "rspec-its"
  gem "rspec-memory"

  gem "yardstick"
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
