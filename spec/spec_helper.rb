# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'bundler'
Bundler.setup(:default, :development)

# Boot up the dummy app
require File.expand_path("../dummy/config/environment.rb",  __FILE__)
if defined? RAILS_GEM_VERSION
  # Bomb out early if we're trying to run rails 2.3 on ruby 1.9.3
  raise "Rails 2.3 does not support running under Ruby 1.9.3+!" if RUBY_VERSION >= "1.9.3"
  # even more rails 2.3 hackity hacks
  require 'test_help'
else
  require "rails/test_help"
end

# Ensure we have our testing DB setup
ActiveRecord::Migrator.migrate File.expand_path("../dummy/db/migrate/", __FILE__)

Rails.backtrace_cleaner.remove_silencers!

require 'simplecov' unless ENV['TRAVIS']
Bundler.require

require 'rubycas-client'

SPEC_TMP_DIR="spec/tmp"

Dir["./spec/support/**/*.rb"].each do |f|
  require f.gsub('.rb','') unless f.end_with? '_spec.rb'
end

require 'database_cleaner'

RSpec.configure do |config|
  config.mock_with :rspec
  config.mock_framework = :rspec
  config.include ActionControllerHelpers

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run_including :focus
  config.run_all_when_everything_filtered = true
  config.fail_fast = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after(:suite) do
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

