source "http://rubygems.org"

gemspec

group :tools do
  gem "simplecov", :require => false
  gem "guard"
  gem "guard-rspec"

  platforms :ruby do
    gem "sqlite3"
  end

  platforms :jruby do
    gem "jruby-openssl"
    gem "activerecord-jdbcsqlite3-adapter"
  end
end
