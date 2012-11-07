# Setup bundler again so we can capture the rails version we're testing against
bundle = Bundler.setup(:default, :development)
rails_version = bundle.inspect.match(/rails\s+\((.+?)\)/)[1]

unless rails_version =~ /^2\.3/
  # Perform rails 3+ style init
  # Load the rails application
  require File.expand_path('../application', __FILE__)

  # Initialize the rails application
  Dummy::Application.initialize!
else # perform rails 2.3 style init
  RAILS_GEM_VERSION = rails_version

  # Bootstrap the Rails environment, frameworks, and default configuration
  require File.join(File.dirname(__FILE__), 'boot23')

  Rails::Initializer.run do |config|
    # set up out app
    # which really means don't do anything because bundler will handle it
  end
end
