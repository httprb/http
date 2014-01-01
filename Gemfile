source 'http://rubygems.org'

gem 'rake'
gem 'jruby-openssl' if defined? JRUBY_VERSION

group :development do
  platforms :ruby_19, :ruby_20 do
    gem 'celluloid-io'
    gem 'guard-rspec'
  end
end

group :test do
  gem 'coveralls', :require => false
  gem 'json', '>= 1.8.1', :platforms => [:jruby, :ruby_18]
  gem 'mime-types', '~> 1.25', :platforms => :ruby_18
  gem 'rspec', '>= 2.14'
end

# Specify your gem's dependencies in http.gemspec
gemspec
