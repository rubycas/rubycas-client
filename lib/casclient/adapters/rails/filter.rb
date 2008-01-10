module CASClient
  module Adapters
    module Rails
      class Filter
        @@config = nil
        @@log = nil
        cattr_reader :config, :log
        
        class << self
          def filter(controller)
            raise "Cannot use the CASClient filter because it has not yet been configured." if config.nil?
            
            client = CASClient::Client.new(config)
            @@log = client.log

            ticket = read_ticket(controller)
            
            if ticket
              client.validate_service_ticket(ticket)
              vr = ticket.response
              if ticket.is_valid?
                log.info("Ticket #{ticket.ticket.inspect} for service #{ticket.service.inspect} belonging to user #{vr.user.inspect} was successfully validated.")
                controller.session[client.session_username_key] = vr.user
                controller.session[client.session_username_key] = vr.extra_attributes
                
                # RubyCAS-Client 1.x used :casfilteruser as it's session username key,
                # so we need to set this here to ensure compatibility with configurations
                # built around the old client.
                controller.session[:casfilteruser] = vr.user
              else
                log.warn("Ticket #{ticket.ticket.inspect} failed validation -- #{vr.failure_code}: #{vr.failure_message}")
                redirect_to_cas_for_authentication(controller, client)
                return false
              end
            else
              redirect_to_cas_for_authentication(controller, client)
              return false
            end
          end
          
          def configure(config)
            @@config = config
            @@config[:logger] = RAILS_DEFAULT_LOGGER unless @@config[:logger]
          end
          
          private
          def read_ticket(controller)
            ticket = controller.params[:ticket]
            
            return nil unless ticket
            
            if ticket =~ /^PT-/
              ProxyTicket.new(ticket, read_service_url(controller), pgt_url, controller.params[:renew])
            else
              ServiceTicket.new(ticket, read_service_url(controller), controller.params[:renew])
            end
          end
          
          def read_service_url(controller)
            if config[:service]
              log.debug("Using explicitly set service url: #{config[:service]}")
              return config[:service]
            end
            
            params = controller.params.dup
            params.delete(:ticket)
            service_url = controller.url_for(params)
            log.debug("Guessed service url: #{service_url.inspect}")
            return service_url
          end
          
          def redirect_to_cas_for_authentication(controller, client)
            service_url = read_service_url(controller)
            redirect_url = client.add_service_to_login_url(service_url)
            log.debug("Redirecting to #{redirect_url.inspect}")
            controller.send(:redirect_to, redirect_url)
          end
        end
      end
    end
  end
end