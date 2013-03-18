#!/usr/bin/env rake
require 'bundler/setup'
require 'rake'
require 'bundler/gem_tasks'

require 'appraisal'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task :default => [:spec]

namespace :spec do
  desc 'run the specs and features against every gemset.'
  task :all do
    system("bundle exec rake -s appraisal spec ;")
  end
end
