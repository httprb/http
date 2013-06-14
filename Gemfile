source 'http://rubygems.org'

gem 'jruby-openssl' if defined? JRUBY_VERSION
gem 'coveralls', :require => false

# Specify your gem's dependencies in http.gemspec
gemspec

group :development do
  gem 'guard-rspec'
  gem 'celluloid-io' if RUBY_VERSION >= "1.9.3"
end
