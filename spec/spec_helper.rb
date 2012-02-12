require 'bundler'
Bundler.setup(:default, :development)
Bundler.require

require 'simplecov'

RSpec.configure do |config|
  #config.include Rack::Test::Methods
  #config.include Webrat::Methods
  #config.include Webrat::Matchers
  #config.include TestHelpers
  #config.include Helpers
  config.mock_with :rspec
  config.mock_framework = :rspec
end

require 'rubycas-client'
