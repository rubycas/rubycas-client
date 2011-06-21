require 'rubygems'
require 'bundler/setup'
require 'casclient'
require 'riot'
require 'riot/rr'
require 'action_pack'

RAILS_ROOT = "#{File.dirname(__FILE__)}/.." unless defined?(RAILS_ROOT)

Riot.reporter = Riot::VerboseStoryReporter
