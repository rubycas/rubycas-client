# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "rubycas-client"
  gem.homepage = "http://github.com/rubycas/rubycas-client"
  gem.license = "MIT"
  gem.summary = "Client library for the Central Authentication Service (CAS) protocol."
  gem.authors = ["Matt Zukowski", "Matt Walker", "Matt Campbell"]
  gem.rdoc_options = ['--main', 'README.rdoc']
  gem.files.exclude '.rvmrc', '.infinity_test', '.rbenv-version', '.rbenv-gemsets'
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

begin
  require 'rspec/core/rake_task'
  desc 'Run RSpecs to confirm that all functionality is working as expected'
  RSpec::Core::RakeTask.new('spec') do |t|
    t.pattern = 'spec/**/*_spec.rb'
  end
  task :default => :spec
rescue LoadError
  puts "Hiding spec tasks because RSpec is not available"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rubycas-client #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
