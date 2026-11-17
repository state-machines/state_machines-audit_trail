# frozen_string_literal: true

appraise 'rails_8.1' do
  gem 'sqlite3', platforms: %i[mri truffleruby]
  # 81.0.pre1 is the first adapter release supporting Rails 8.1; without the
  # prerelease requirement Bundler falls back to the Rails 4-era 1.3.22
  gem 'activerecord-jdbcsqlite3-adapter', '>= 81.0.pre1', platform: :jruby
  # The adapter accepts jdbc-sqlite3 ~> 3.8, but cannot open a connection
  # with the 3.8 driver
  gem 'jdbc-sqlite3', '>= 3.46', platform: :jruby
  gem 'activerecord', '~> 8.1.0'
  gem 'state_machines-activerecord'
end

# NOTE: `appraisal generate` will copy the root Gemfile's plain
# `gem 'railties', '>= 7.1'` into gemfiles/rails_edge.gemfile verbatim,
# which conflicts with activerecord/activemodel being sourced from
# rails/rails@main here (mismatched activesupport versions). After
# regenerating, hand-edit that one line in gemfiles/rails_edge.gemfile to
# `gem "railties", github: "rails/rails", branch: "main"` to match.
# No JRuby on edge: edge railties pulls in herb, a C extension JRuby cannot build
appraise 'rails_edge' do
  gem 'sqlite3', platforms: %i[mri truffleruby]
  gem 'activerecord', github: 'rails/rails', branch: 'main'
  gem 'activemodel', github: 'rails/rails', branch: 'main'
  gem 'state_machines-activerecord'
end
