# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

Rake::TestTask.new(:test) do |task|
  task.libs << 'spec'
  task.test_files = FileList['spec/**/*_test.rb']
  task.verbose = true
end

RuboCop::RakeTask.new

task default: %i[rubocop test]
