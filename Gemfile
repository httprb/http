source "https://rubygems.org"

gem "rake"

group :development do
  gem "celluloid-io"
  gem "guard"
  gem "guard-rspec", :require => false
  gem "nokogiri", :require => false
  gem "pry"

  platforms :ruby_19, :ruby_20 do
    gem "pry-debugger"
    gem "pry-stack_explorer"
  end
end

group :test do
  gem "backports"
  gem "coveralls"
  gem "simplecov", ">= 0.9"
  gem "json",      ">= 1.8.1"
  gem "rubocop",   "=  0.39.0"
  gem "rspec",     "~> 3.0"
  gem "rspec-its"
  gem "yardstick"
  gem "certificate_authority", :require => false
end

group :doc do
  gem "kramdown"
  gem "yard"
end

# Specify your gem's dependencies in http.gemspec
gemspec
