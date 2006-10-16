require 'cas_auth'
require 'cas_proxy_callback_controller'

#CAS::Filter.logger = RAILS_DEFAULT_LOGGER if !RAILS_DEFAULT_LOGGER.nil?
#CAS::Filter.logger = config.logger if !config.logger.nil?

CAS::Filter.logger = Logger.new("#{RAILS_ROOT}/log/cas_filter.log", 'weekly')
CAS::Filter.logger.level = Logger::DEBUG

#class ActionController::Base
#  append_before_filter CAS::Filter
#end
