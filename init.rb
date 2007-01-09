require 'cas_auth'
require 'cas_logger'
require 'cas_proxy_callback_controller'

#CAS::Filter.logger = RAILS_DEFAULT_LOGGER if !RAILS_DEFAULT_LOGGER.nil?
#CAS::Filter.logger = config.logger if !config.logger.nil?

CAS::Filter.logger = CAS::Logger.new("#{RAILS_ROOT}/log/cas_client_#{RAILS_ENV}.log", 1024000)
CAS::Filter.logger.formatter = CAS::Logger::Formatter.new

#if RAILS_ENV == "production"
#  CAS::Filter.logger.level = Logger::WARN
#else
  CAS::Filter.logger.level = Logger::DEBUG
#end


#class ActionController::Base
#  append_before_filter CAS::Filter
#end