require 'bundler/gem_tasks'
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = "./spec/**/*_spec.rb"
  task.rspec_opts = ['--color']
end

if ENV['APPRAISAL_INITIALIZED'] || ENV['TRAVIS']
  task :default => :spec
else
  require 'appraisal'
  Appraisal::Task.new
  task :default => :appraisal
end
