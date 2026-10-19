# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'railties', '>= 7.1'
gem 'rubocop'
gem 'rubocop-minitest'
gem 'rubocop-performance'

# Development dependencies for testing (not in gemspec to avoid Appraisal conflicts)
gem 'activerecord', '>= 8.1'
gem 'sqlite3', '~> 2.1'
gem 'state_machines-activerecord'

platforms :mri do
  gem 'padded_cell', '~> 0.2'
end
