require 'uri'
require 'cgi'
require 'net/https'
require 'rexml/document'

begin
  require 'active_support'
rescue LoadError
  require 'rubygems'
  require 'active_support'
end

$: << File.expand_path(File.dirname(__FILE__))

module CASClient
  class CASException < Exception
  end

  # Wraps a real Logger. If no real Logger is set, then this wrapper
  # will quietly swallow any logging calls.
  class Logger
    def initialize(real_logger=nil)
      set_logger(real_logger)
    end
    # Assign the 'real' Logger instance that this dummy instance wraps around.
    def set_real_logger(real_logger)
      @real_logger = real_logger
    end
    # Log using the appropriate method if we have a logger
    # if we dont' have a logger, gracefully ignore.
    def method_missing(name, *args)
      if @real_logger && @real_logger.respond_to?(name)
        @real_logger.send(name, *args)
      end
    end
  end
end

require 'casclient/tickets'
require 'casclient/responses'
require 'casclient/client'
require 'casclient/version'