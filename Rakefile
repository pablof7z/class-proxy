require "bundler"

Bundler.setup
Bundler.require(:default)
require 'rake'
require 'rspec/core/rake_task'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'classproxy/version'

RSpec::Core::RakeTask.new("spec") do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

desc "Run watchr"
task :watchr do
  sh %{bundle exec watchr .watchr}
end

task gem: :build
task :build do
  system "gem build classproxy.gemspec"
end

task release: :build do
  version = ClassProxy::VERSION
  system "git tag -a v#{version} -m 'Tagging #{version}'"
  system "git push --tags"
  system "gem push classproxy-#{version}"
  system "rm classproxy-#{version}"
end

task default: :spec