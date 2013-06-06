# A sample Gemfile
source "https://rubygems.org"

gem 'standalone_migrations'
gem 'activerecord'
gem 'httparty'
gem 'ffi-geos'
gem 'activerecord-postgis-adapter', git: "https://github.com/GUI/activerecord-postgis-adapter.git", branch: 'jdbc'

platform :ruby do
  gem 'pg'
end

platform :jruby do
  gem 'ruby-processing'
  gem 'jruby-openssl'
  gem 'activerecord-jdbcpostgresql-adapter'
end
