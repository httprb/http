#!/usr/bin/env rake
require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

task :test => :spec

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    $stderr.puts "RuboCop is disabled"
  end
end

require "yardstick/rake/measurement"
Yardstick::Rake::Measurement.new do |measurement|
  measurement.output = "measurement/report.txt"
end

require "yardstick/rake/verify"
Yardstick::Rake::Verify.new do |verify|
  verify.require_exact_threshold = false
  verify.threshold = 55
end

task :generate_status_codes do
  require "http"
  require "nokogiri"

  url = "http://www.iana.org/assignments/http-status-codes/http-status-codes.xml"
  xml = Nokogiri::XML HTTP.get url
  known_codes = {
    418 => "I'm a Teapot"
  }

  xml.xpath("//xmlns:record").each do |node|
    code = node.xpath("xmlns:value").text.to_s
    desc = node.xpath("xmlns:description").text.to_s

    next if "Unassigned" == desc || "(Unused)" == desc

    known_codes[code.to_i] = desc
  end

  File.open("./lib/http/response/status/reasons.rb", "w") do |io|
    reasons = known_codes.keys.sort.map do |code|
      "\n              #{code} => #{known_codes[code].inspect}"
    end

    io.puts <<-TPL.gsub(/^[ ]{6}/, "")
      # frozen_string_literal: true
      # AUTO-GENERATED FILE, DO NOT CHANGE IT MANUALLY

      require "delegate"

      module HTTP
        class Response
          class Status < ::Delegator
            # Code to Reason map
            #
            # @example Usage
            #
            #   REASONS[400] # => "Bad Request"
            #   REASONS[414] # => "Request-URI Too Long"
            #
            # @return [Hash<Fixnum => String>]
            REASONS = {#{reasons.join ','}
            }.each { |_, v| v.freeze }.freeze
          end
        end
      end
    TPL
  end
end

task :default => [:spec, :rubocop, :verify_measurements]
