module CASClient
  module Frameworks
    module Rails
      class Filter
        cattr_reader :config, :log, :client
        
        # These are initialized when you call configure.
        @@config = nil
        @@client = nil
        @@log = nil
        
        class << self
          def filter(controller)
            raise "Cannot use the CASClient filter because it has not yet been configured." if config.nil?

            st = read_ticket(controller)
            
            lst = controller.session[:cas_last_valid_ticket]
            
            if st && lst && lst.ticket == st.ticket && lst.service == st.service
              # warn() rather than info() because we really shouldn't be re-validating the same ticket. 
              # The only time when this is acceptable is if the user manually does a refresh and the ticket
              # happens to be in the URL.
              log.warn("Re-using previously validated ticket since the new ticket and service are the same.")
              st = lst
            end
            
            if st
              client.validate_service_ticket(st) unless st.has_been_validated?
              vr = st.response
              
              if st.is_valid?
                log.info("Ticket #{st.ticket.inspect} for service #{st.service.inspect} belonging to user #{vr.user.inspect} is VALID.")
                controller.session[client.username_session_key] = vr.user
                controller.session[client.extra_attributes_session_key] = vr.extra_attributes
                
                # RubyCAS-Client 1.x used :casfilteruser as it's username session key,
                # so we need to set this here to ensure compatibility with configurations
                # built around the old client.
                controller.session[:casfilteruser] = vr.user
                
                # Store the ticket in the session to avoid re-validating the same service
                # ticket with the CAS server.
                controller.session[:cas_last_valid_ticket] = st
                
                if vr.pgt_iou
                  log.info("Receipt has a proxy-granting ticket IOU. Attempting to retrieve the proxy-granting ticket...")
                  pgt = client.retrieve_proxy_granting_ticket(vr.pgt_iou)
                  if pgt
                    log.debug("Got PGT #{pgt.ticket.inspect} for PGT IOU #{pgt.iou.inspect}. This will be stored in the session.")
                    controller.session[:cas_pgt] = pgt
                    # For backwards compatibility with RubyCAS-Client 1.x configurations...
                    controller.session[:casfilterpgt] = pgt
                  else
                    log.error("Failed to retrieve a PGT for PGT IOU #{vr.pgt_iou}!")
                  end
                end
                
                return true
              else
                log.warn("Ticket #{st.ticket.inspect} failed validation -- #{vr.failure_code}: #{vr.failure_message}")
                redirect_to_cas_for_authentication(controller)
                return false
              end
            elsif !config[:authenticate_on_every_request] && controller.session[client.username_session_key]
              # Don't re-authenticate with the CAS server if we already previously authenticated and the
              # :authenticate_on_every_request option is disabled (it's disabled by default).
              log.debug "Existing local CAS session detected for #{controller.session[client.username_session_key].inspect}. "+
                "User will not be re-authenticated."
              return true
            else
              if returning_from_gateway?(controller)
                log.info "Returning from CAS gateway without authentication."
                
                if use_gatewaying?
                  log.info "This CAS client is configured to use gatewaying, so we will permit the user to continue without authentication."
                  return true
                else
                  log.warn "The CAS client is NOT configured to allow gatewaying, yet this request was gatewayed. Something is not right!"
                end
              end
              
              redirect_to_cas_for_authentication(controller)
              return false
            end
          end
          
          def configure(config)
            @@config = config
            @@config[:logger] = RAILS_DEFAULT_LOGGER unless @@config[:logger]
            @@client = CASClient::Client.new(config)
            @@log = client.log
          end
          
          def use_gatewaying?
            @@config[:use_gatewaying]
          end
          
          def returning_from_gateway?(controller)
            controller.session[:cas_sent_to_gateway]
          end
          
          def redirect_to_cas_for_authentication(controller)
            service_url = read_service_url(controller)
            redirect_url = client.add_service_to_login_url(service_url)
            
            if use_gatewaying?
              controller.session[:cas_sent_to_gateway] = true
              redirect_url << "&gateway=true"
            else
              controller.session[:cas_sent_to_gateway] = false
            end
            
            log.debug("Redirecting to #{redirect_url.inspect}")
            controller.send(:redirect_to, redirect_url)
          end
          
          private
          def read_ticket(controller)
            ticket = controller.params[:ticket]
            
            return nil unless ticket
            
            log.debug("Request contains ticket #{ticket.inspect}.")
            
            if ticket =~ /^PT-/
              ProxyTicket.new(ticket, read_service_url(controller), controller.params[:renew])
            else
              ServiceTicket.new(ticket, read_service_url(controller), controller.params[:renew])
            end
          end
          
          def read_service_url(controller)
            if config[:service_url]
              log.debug("Using explicitly set service url: #{config[:service_url]}")
              return config[:service_url]
            end
            
            params = controller.params.dup
            params.delete(:ticket)
            service_url = controller.url_for(params)
            log.debug("Guessed service url: #{service_url.inspect}")
            return service_url
          end
        end
      end
    
      class GatewayFilter < Filter
        def self.use_gatewaying?
          return true unless @@config[:use_gatewaying] == false
        end
      end
    end
  end
end