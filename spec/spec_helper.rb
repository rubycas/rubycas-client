require 'bundler'
Bundler.setup(:default, :development)
require 'simplecov' unless ENV['TRAVIS'] || defined?(JRUBY_VERSION)
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
    ActiveRecordHelpers.setup_active_record
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after(:suite) do
    ActiveRecordHelpers.teardown_active_record
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

