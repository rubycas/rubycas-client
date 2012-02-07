module CASClient
  module Frameworks
    module Rails
      class Filter
        cattr_reader :config, :log, :client, :fake_user, :fake_extra_attribues
        
        # These are initialized when you call configure.
        @@config = nil
        @@client = nil
        @@log = nil
        @@fake_user = nil
        @@fake_extra_attributes = nil
        
        class << self
          def filter(controller)
            raise "Cannot use the CASClient filter because it has not yet been configured." if config.nil?
            
            if @@fake_user
              controller.session[client.username_session_key] = @@fake_user
              controller.session[:casfilteruser] = @@fake_user
              controller.session[client.extra_attributes_session_key] = @@fake_extra_attributes if @@fake_extra_attributes
              return true
            end
            
            last_st = controller.session[:cas_last_valid_ticket]
            last_st_service = controller.session[:cas_last_valid_ticket_service]
            
            if single_sign_out(controller)
              controller.send(:render, :text => "CAS Single-Sign-Out request intercepted.")
              return false 
            end

            st = read_ticket(controller)
            
            if st && last_st && 
                last_st == st.ticket && 
                last_st_service == st.service
              # warn() rather than info() because we really shouldn't be re-validating the same ticket. 
              # The only situation where this is acceptable is if the user manually does a refresh and 
              # the same ticket happens to be in the URL.
              log.warn("Re-using previously validated ticket since the ticket id and service are the same.")
              return true
            elsif last_st &&
                !config[:authenticate_on_every_request] && 
                controller.session[client.username_session_key]
              # Re-use the previous ticket if the user already has a local CAS session (i.e. if they were already
              # previously authenticated for this service). This is to prevent redirection to the CAS server on every
              # request.
              #
              # This behaviour can be disabled (so that every request is routed through the CAS server) by setting
              # the :authenticate_on_every_request config option to true. However, this is not desirable since
              # it will almost certainly break POST request, AJAX calls, etc.
              log.debug "Existing local CAS session detected for #{controller.session[client.username_session_key].inspect}. "+
                "Previous ticket #{last_st.inspect} will be re-used."
              return true
            end
            
            if st
              client.validate_service_ticket(st) unless st.has_been_validated?
              
              if st.is_valid?
                #if is_new_session
                  log.info("Ticket #{st.ticket.inspect} for service #{st.service.inspect} belonging to user #{st.user.inspect} is VALID.")
                  controller.session[client.username_session_key] = st.user.dup
                  controller.session[client.extra_attributes_session_key] = HashWithIndifferentAccess.new(st.extra_attributes) if st.extra_attributes
                  
                  if st.extra_attributes
                    log.debug("Extra user attributes provided along with ticket #{st.ticket.inspect}: #{st.extra_attributes.inspect}.")
                  end
                  
                  # RubyCAS-Client 1.x used :casfilteruser as it's username session key,
                  # so we need to set this here to ensure compatibility with configurations
                  # built around the old client.
                  controller.session[:casfilteruser] = st.user
                  
                  if config[:enable_single_sign_out]
                    client.ticket_store.store_service_session_lookup(st, controller)
                  end
                #end
              
                # Store the ticket in the session to avoid re-validating the same service
                # ticket with the CAS server.
                controller.session[:cas_last_valid_ticket] = st.ticket
                controller.session[:cas_last_valid_ticket_service] = st.service
                
                if st.pgt_iou
                  unless controller.session[:cas_pgt] && controller.session[:cas_pgt].ticket && controller.session[:cas_pgt].iou == st.pgt_iou
                    log.info("Receipt has a proxy-granting ticket IOU. Attempting to retrieve the proxy-granting ticket...")
                    pgt = client.retrieve_proxy_granting_ticket(st.pgt_iou)

                    if pgt
                      log.debug("Got PGT #{pgt.ticket.inspect} for PGT IOU #{pgt.iou.inspect}. This will be stored in the session.")
                      controller.session[:cas_pgt] = pgt
                      # For backwards compatibility with RubyCAS-Client 1.x configurations...
                      controller.session[:casfilterpgt] = pgt
                    else
                      log.error("Failed to retrieve a PGT for PGT IOU #{st.pgt_iou}!")
                    end
                  else
                    log.info("PGT is present in session and PGT IOU #{st.pgt_iou} matches the saved PGT IOU.  Not retrieving new PGT.")
                  end
                end
                return true
              else
                log.warn("Ticket #{st.ticket.inspect} failed validation -- #{st.failure_code}: #{st.failure_message}")
                unauthorized!(controller, st)
                return false
              end
            else # no service ticket was present in the request
              if returning_from_gateway?(controller)
                log.info "Returning from CAS gateway without authentication."

                # unset, to allow for the next request to be authenticated if necessary
                controller.session[:cas_sent_to_gateway] = false

                if use_gatewaying?
                  log.info "This CAS client is configured to use gatewaying, so we will permit the user to continue without authentication."
                  controller.session[client.username_session_key] = nil
                  return true
                else
                  log.warn "The CAS client is NOT configured to allow gatewaying, yet this request was gatewayed. Something is not right!"
                end
              end
              
              unauthorized!(controller)
              return false
            end
          rescue OpenSSL::SSL::SSLError
            log.error("SSL Error: hostname was not match with the server certificate. You can try to disable the ssl verification with a :force_ssl_verification => false in your configurations file.")
            unauthorized!(controller)
            return false
          end
          
          def configure(config)
            @@config = config
            @@config[:logger] = ::Rails.logger unless @@config[:logger]
            @@client = CASClient::Client.new(config)
            @@log = client.log
          end
          
          # used to allow faking for testing
          # with cucumber and other tools.
          # use like 
          #  CASClient::Frameworks::Rails::Filter.fake("homer")
          # you can also fake extra attributes by including a second parameter
          #  CASClient::Frameworks::Rails::Filter.fake("homer", {:roles => ['dad', 'husband']})
          def fake(username, extra_attributes = nil)
            @@fake_user = username
            @@fake_extra_attributes = extra_attributes
          end
          
          def use_gatewaying?
            @@config[:use_gatewaying]
          end
          
          # Returns the login URL for the current controller. 
          # Useful when you want to provide a "Login" link in a GatewayFilter'ed
          # action. 
          def login_url(controller)
            service_url = read_service_url(controller)
            url = client.add_service_to_login_url(service_url)
            log.debug("Generated login url: #{url}")
            return url
          end

          # allow controllers to reuse the existing config to auto-login to
          # the service
          # 
          # Use this from within a controller. Pass the controller, the
          # login-credentials and the path that you want the user
          # resdirected to on success.
          #
          # When writing a login-action you must check the return-value of
          # the response to see if it failed!
          #
          # If it worked - you need to redirect the user to the service -
          # path, because that has the ticket that will *actually* log them
          # into your system
          #
          # example:
          # def autologin
          #   resp = CASClient::Frameworks::Rails::Filter.login_to_service(self, credentials, dashboard_url)
          #   if resp.is_faiulure?
          #     flash[:error] = 'Login failed'
          #     render :action => 'login'
          #   else
          #     return redirect_to(@resp.service_redirect_url)
          #   end
          # end
          def login_to_service(controller, credentials, return_path)
            resp = @@client.login_to_service(credentials, return_path)
            if resp.is_failure?
              log.info("Validation failed for service #{return_path.inspect} reason: '#{resp.failure_message}'")
            else
              log.info("Ticket #{resp.ticket.inspect} for service #{return_path.inspect} is VALID.")
            end
            
            resp
          end
          
          # Clears the given controller's local Rails session, does some local 
          # CAS cleanup, and redirects to the CAS logout page. Additionally, the
          # <tt>request.referer</tt> value from the <tt>controller</tt> instance 
          # is passed to the CAS server as a 'destination' parameter. This 
          # allows RubyCAS server to provide a follow-up login page allowing
          # the user to log back in to the service they just logged out from 
          # using a different username and password. Other CAS server 
          # implemenations may use this 'destination' parameter in different 
          # ways. 
          # If given, the optional <tt>service</tt> URL overrides 
          # <tt>request.referer</tt>.
          def logout(controller, service = nil)
            referer = service || controller.request.referer
            st = controller.session[:cas_last_valid_ticket]
            @@client.ticket_store.cleanup_service_session_lookup(st) if st
            controller.send(:reset_session)
            controller.send(:redirect_to, client.logout_url(referer))
          end
          
          def unauthorized!(controller, vr = nil)
            format = nil
            unless controller.request.format.nil?
              format = controller.request.format.to_sym
            end
            format = (format == :js ? :json : format)
            case format
            when :xml, :json
              if vr
                case format
                when :xml
                  controller.send(:render, :xml => { :error => vr.failure_message }.to_xml(:root => 'errors'), :status => :unauthorized)
                when :json
                  controller.send(:render, :json => { :errors => { :error => vr.failure_message }}, :status => :unauthorized)
                end
              else
                controller.send(:head, :unauthorized)
              end
            else
              redirect_to_cas_for_authentication(controller)
            end
          end
          
          def redirect_to_cas_for_authentication(controller)
            redirect_url = login_url(controller)
            
            if use_gatewaying?
              controller.session[:cas_sent_to_gateway] = true
              redirect_url << "&gateway=true"
            else
              controller.session[:cas_sent_to_gateway] = false
            end
            
            if controller.session[:previous_redirect_to_cas] &&
                controller.session[:previous_redirect_to_cas] > (Time.now - 1.second)
              log.warn("Previous redirect to the CAS server was less than a second ago. The client at #{controller.request.remote_ip.inspect} may be stuck in a redirection loop!")
              controller.session[:cas_validation_retry_count] ||= 0
              
              if controller.session[:cas_validation_retry_count] > 3
                log.error("Redirection loop intercepted. Client at #{controller.request.remote_ip.inspect} will be redirected back to login page and forced to renew authentication.")
                redirect_url += "&renew=1&redirection_loop_intercepted=1"
              end
              
              controller.session[:cas_validation_retry_count] += 1
            else
              controller.session[:cas_validation_retry_count] = 0
            end
            controller.session[:previous_redirect_to_cas] = Time.now
            
            log.debug("Redirecting to #{redirect_url.inspect}")
            controller.send(:redirect_to, redirect_url)
          end
          
          private
          def single_sign_out(controller)
            
            # Avoid calling raw_post (which may consume the post body) if
            # this seems to be a file upload
            if content_type = controller.request.headers["CONTENT_TYPE"] &&
                content_type =~ %r{^multipart/}
              return false
            end
            
            if controller.request.post? &&
                controller.params['logoutRequest'] &&
                #This next line checks the logoutRequest value for both its regular and URI.escape'd form. I couldn't get
                #it to work without URI.escaping it from rubycas server's side, this way it will work either way.
                [controller.params['logoutRequest'],URI.unescape(controller.params['logoutRequest'])].find{|xml| xml =~
                    %r{^<samlp:LogoutRequest.*?<samlp:SessionIndex>(.*)</samlp:SessionIndex>}m}
              # TODO: Maybe check that the request came from the registered CAS server? Although this might be
              #       pointless since it's easily spoofable...
              si = $~[1]
              
              unless config[:enable_single_sign_out]
                log.warn "Ignoring single-sign-out request for CAS session #{si.inspect} because ssout functionality is not enabled (see the :enable_single_sign_out config option)."
                return false
              end
              
              log.debug "Intercepted single-sign-out request for CAS session #{si.inspect}."

              @@client.ticket_store.process_single_sign_out(si)             
              
              # Return true to indicate that a single-sign-out request was detected
              # and that further processing of the request is unnecessary.
              return true
            end
            
            # This is not a single-sign-out request.
            return false
          end
          
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
          
          def returning_from_gateway?(controller)
            controller.session[:cas_sent_to_gateway]
          end

          def read_service_url(controller)
            if config[:service_url]
              log.debug("Using explicitly set service url: #{config[:service_url]}")
              return config[:service_url]
            end

            params = {}.with_indifferent_access
            params.update(controller.request.query_parameters)
            params.update(controller.request.path_parameters)
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
