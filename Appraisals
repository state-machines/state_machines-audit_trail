# frozen_string_literal: true

appraise 'rails_8.1' do
  gem 'sqlite3', platforms: %i[mri rbx]
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 8.1.0'
end

appraise 'rails_edge' do
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', github: 'rails/rails', branch: 'main'
  gem 'activemodel', github: 'rails/rails', branch: 'main'
end
