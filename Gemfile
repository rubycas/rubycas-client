source "http://rubygems.org"

group :development do
  gem "json"
  gem "rspec"
  gem "bundler", ">= 1.0"
  gem "jeweler"
  gem "actionpack"
  gem "activerecord"
  gem "rake"
  gem "simplecov", :require => false
  gem "guard"
  gem "guard-rspec"
  gem "database_cleaner"

  platforms :ruby do
    gem "sqlite3"
  end

  platforms :jruby do
    gem "jruby-openssl"
    gem "activerecord-jdbch2-adapter"
  end
end

gem "activesupport", :require => "active_support"

