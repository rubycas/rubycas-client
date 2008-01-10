module CASClient
  module Adapters
    module Rails
      class Filter
        @@config = nil
        cattr_reader :config
        
        def self.filter(controller)
          raise "Cannot use the CASClient filter because it has not yet been configured." if config.nil?
          
          client = CASClient::Client.new(config)
          log = client.log
          
          ticket = controller.params[:ticket]
          
          if ticket
            vr = client.validate_service_ticket(ticket)
            if vr.is_successful?
              log.info("Ticket #{ticket.inspect} for service #{vr.service} belonging to user #{vr.inspect} was successfully validated.")
              controllers.session[client.session_username_key] = vr.user
              controllers.session[client.session_username_key] = vr.extra_attributes
              
              # RubyCAS-Client 1.x used :casfilteruser as it's session username key,
              # so we need to set this here to ensure compatibility with configurations
              # built around the old client.
              controllers.session[:casfilteruser] = vr.user
            else
              log.warn("Ticket #{ticket.inspect} failed validation: #{vr.failure_code}: #{vr.failure_message}")
            end
          end
        end
        
        def self.configure(config)
          @@config = config
        end
      end
    end
  end
end