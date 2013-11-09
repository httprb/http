source 'http://rubygems.org'

gem 'jruby-openssl' if defined? JRUBY_VERSION

group :development do
  platforms :ruby_19, :ruby_20 do
    gem 'celluloid-io'
    gem 'guard-rspec'
  end
end

group :test do
  gem 'coveralls', :require => false
  gem 'mime-types', '~> 1.25', :platforms => :ruby_18
end

# Specify your gem's dependencies in http.gemspec
gemspec
