# -*- encoding: utf-8 -*-
require File.expand_path("../lib/http/version", __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri", "Erik Michaels-Ober", "Aleksey V. Zapparov"]
  gem.email         = ["bascule@gmail.com"]

  gem.description   = <<-DESCRIPTION.strip.gsub(/\s+/, " ")
    An easy-to-use client library for making requests from Ruby.
    It uses a simple method chaining system for building requests,
    similar to Python's Requests.
  DESCRIPTION

  gem.summary       = "HTTP should be easy"
  gem.homepage      = "https://github.com/httprb/http.rb"
  gem.licenses      = ["MIT"]

  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "http"
  gem.require_paths = ["lib"]
  gem.version       = HTTP::VERSION

  gem.add_runtime_dependency "http_parser.rb", "~> 0.6.0"
  gem.add_runtime_dependency "http-form_data", "~> 1.0.0"
  gem.add_runtime_dependency "rack-cache",     "~> 1.2"

  gem.add_development_dependency "bundler", "~> 1.0"
end
