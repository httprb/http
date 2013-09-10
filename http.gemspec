# -*- encoding: utf-8 -*-
require File.expand_path('../lib/http/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "HTTP so awesome it will lure Catherine Zeta Jones into your unicorn petting zoo"
  gem.summary       = "HTTP should be easy"
  gem.homepage      = "https://github.com/tarcieri/http"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "http"
  gem.require_paths = ["lib"]
  gem.version       = HTTP::VERSION

  gem.add_runtime_dependency 'http_parser.rb'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '>= 2.11'
  gem.add_development_dependency 'json'
end
