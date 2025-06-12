appraise 'rails_7.1' do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 7.1.0'
end

appraise 'rails_7.2' do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 7.2.0'
end

appraise 'rails_8.0' do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 8.0.0'
end

appraise "rails_edge" do
  gem "sqlite3", platforms: :mri
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", github: 'rails/rails',  branch: 'main'
  gem "activemodel", github: 'rails/rails', branch: 'main'
end
