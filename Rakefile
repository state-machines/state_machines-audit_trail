# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'shellwords'

Rake::TestTask.new(:minitest) do |task|
  task.libs.push 'lib'
  task.libs.push 'test'
  task.pattern = 'test/**/*_test.rb'
  task.verbose = true
end

# Load Rails tasks from dummy app to get db:test:prepare
APP_RAKEFILE = File.expand_path('test/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake' if File.exist?(APP_RAKEFILE)

begin
  # rubocop is only a dependency of the root Gemfile, not of the gemspec or
  # the Appraisal-generated gemfiles/*.gemfile, so it isn't available when
  # running `bundle exec rake` under BUNDLE_GEMFILE=gemfiles/rails_*.gemfile.
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  nil
end

desc 'Run the test suite (padded_cell on CRuby, plain Minitest elsewhere)'
if RUBY_ENGINE == 'ruby'
  task :test do
    sh 'padded_cell', *Shellwords.split(ENV.fetch('TESTOPTS', ''))
  end
else
  task test: :minitest
end

task default: :test
