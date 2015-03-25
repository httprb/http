source 'http://rubygems.org'

gem 'rake', '~> 10.1.1'
gem 'jruby-openssl' if defined? JRUBY_VERSION

group :development do
  gem 'pry'
  platforms :ruby_19, :ruby_20 do
    gem 'pry-debugger'
    gem 'pry-stack_explorer'
  end
  platforms :ruby_19, :ruby_20, :ruby_21 do
    gem 'celluloid-io'
    gem 'guard-rspec'
  end
end

group :test do
  gem 'backports'
  gem 'coveralls'
  gem 'json', '>= 1.8.1', :platforms => [:jruby, :rbx, :ruby_18, :ruby_19]
  gem 'mime-types', '~> 1.25', :platforms => [:jruby, :ruby_18]
  gem 'rest-client', '~> 1.6.0', :platforms => [:jruby, :ruby_18]
  gem 'rspec', '~> 2.14'
  gem 'rubocop', '~> 0.24.0', :platforms => [:ruby_19, :ruby_20, :ruby_21]
  gem 'simplecov', '>= 0.9'
  gem 'yardstick'
  gem 'certificate_authority'
  gem 'activemodel', '~> 3.0'
  gem 'i18n', '~> 0.6.0'
end

# Specify your gem's dependencies in http.gemspec
gemspec
