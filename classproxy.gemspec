$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'classproxy/version'

Gem::Specification.new do |s|
  s.name         = 'classproxy'
  s.version      = ClassProxy::VERSION
  s.authors      = ['Pablo Fernandez']
  s.email        = ['heelhook@littleq.net']
  s.summary      = 'A generic class proxy for your classes'
  s.description  = 'A generic (yet ActiveRecord compliant) class proxy to setup proxy methods for your classes'

  s.add_runtime_dependency "activesupport"

  s.files        = Dir.glob("lib/**/*") + %w(LICENSE README.md Rakefile)
  s.require_path = 'lib'
end