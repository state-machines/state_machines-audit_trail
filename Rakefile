# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

Rake::TestTask.new(:test) do |task|
  task.libs.push 'lib'
  task.libs.push 'test'
  task.pattern = 'test/**/*_test.rb'
  task.verbose = true
end

# Load Rails tasks from dummy app to get db:test:prepare
APP_RAKEFILE = File.expand_path('test/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake' if File.exist?(APP_RAKEFILE)

RuboCop::RakeTask.new

task default: %i[rubocop test]
