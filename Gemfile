source "http://rubygems.org"

gemspec

group :tools do
  gem "simplecov", :require => false
  gem "guard"
  gem "guard-rspec"
  gem "guard-bundler"
  gem "fuubar"
  gem "rb-fsevent"
  gem "growl", :group => :darwin

  platforms :ruby do
    gem "sqlite3"
  end

  platforms :jruby do
    gem "jruby-openssl"
    gem "activerecord-jdbcsqlite3-adapter"
  end
end
