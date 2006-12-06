require 'roundhouse'
require 'logger'

# this overrides clean_logger.rb in Rails that pretty much completely breaks logging #!@%*(#@*$&%!!...
module CAS
  class Logger < ::Logger
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      @default_formatter = CAS::Logger::Formatter.new
      super
    end
  
    def format_message(severity, datetime, progrname, msg)
      (@formatter || @default_formatter).call(severity, datetime, progname, msg)
    end
    
    class Formatter < ::Logger::Formatter
      Format = "[%s#%d] %5s -- %s: %s\n"
      
      def call(severity, time, progname, msg)
        Format % [format_datetime(time), $$, severity, progname, msg2str(msg)]
      end
    end
  end
end