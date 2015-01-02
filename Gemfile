source 'https://rubygems.org'

gem 'jruby-openssl' if defined? JRUBY_VERSION
gem 'rake'

group :development do
  gem 'celluloid-io'
  gem 'guard'
  gem 'guard-rspec'
  gem 'pry'

  platforms :ruby_19, :ruby_20 do
    gem 'pry-debugger'
    gem 'pry-stack_explorer'
  end
end

group :test do
  gem 'backports'
  gem 'coveralls'
  gem 'json',         '>= 1.8.1'
  gem 'mime-types',   '~> 1.25',  :platforms => [:jruby]
  gem 'rest-client',  '~> 1.6.0', :platforms => [:jruby]
  gem 'rspec',        '~> 3.0'
  gem 'rspec-its'
  gem 'rubocop',      '~> 0.25.0'
  gem 'simplecov',    '>= 0.9'
  gem 'yardstick'
end

group :doc do
  gem 'redcarpet'
  gem 'yard'
end

# Specify your gem's dependencies in http.gemspec
gemspec
