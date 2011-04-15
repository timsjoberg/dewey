# -*- encoding: utf-8 -*-
require File.expand_path("../lib/dewey/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "dewey"
  s.version     = Dewey::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = []
  s.email       = []
  s.homepage    = "http://rubygems.org/gems/dewey"
  s.summary     = "Manage your TV collection"
  s.description = "Guesses show/episode information and puts things in the right place"

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "dewey"

  s.add_runtime_dependency "tvdb"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
