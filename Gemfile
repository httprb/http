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
  gem 'coveralls', :require => false
  gem 'json', '>= 1.8.1', :platforms => [:jruby, :rbx, :ruby_18, :ruby_19]
  gem 'mime-types', '~> 1.25', :platforms => [:jruby, :ruby_18]
  gem 'rspec', '>= 2.14'
  gem 'rubocop', '>= 0.19', :platforms => [:ruby_19, :ruby_20, :ruby_21]
  gem 'simplecov', :require => false
  gem 'yardstick'
end

# Specify your gem's dependencies in http.gemspec
gemspec
