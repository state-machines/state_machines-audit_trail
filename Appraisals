# frozen_string_literal: true

appraise 'rails_8.1' do
  gem 'sqlite3', platforms: %i[mri rbx]
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 8.1.0'
  gem 'state_machines-activerecord'
end

# NOTE: `appraisal generate` will copy the root Gemfile's plain
# `gem 'railties', '>= 7.1'` into gemfiles/rails_edge.gemfile verbatim,
# which conflicts with activerecord/activemodel being sourced from
# rails/rails@main here (mismatched activesupport versions). After
# regenerating, hand-edit that one line in gemfiles/rails_edge.gemfile to
# `gem "railties", github: "rails/rails", branch: "main"` to match.
appraise 'rails_edge' do
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', github: 'rails/rails', branch: 'main'
  gem 'activemodel', github: 'rails/rails', branch: 'main'
  gem 'state_machines-activerecord'
end
