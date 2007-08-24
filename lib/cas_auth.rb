require 'cgi'
require 'logger'

# these requires are needed when outside of a Rails app context (e.g. in unit tests)
require 'rubygems'
require 'active_support'
require 'action_controller'

require File.dirname(File.expand_path(__FILE__))+'/cas'

module CAS
  # The DummyLogger is a class which might pass through to a real Logger
  # if one is assigned. However, it can gracefully swallow any logging calls
  # if there is now Logger assigned.
  class LoggerWrapper
    def initialize(logger=nil)
      set_logger(logger)
    end
    # Assign the 'real' Logger instance that this dummy instance wraps around.
    def set_logger(logger)
      @logger = logger
    end
    # log using the appropriate method if we have a logger
    # if we dont' have a logger, ignore completely.
    def method_missing(name, *args)
      if @logger && @logger.respond_to?(name)
        @logger.send(name, *args)
      end
    end
  end

  LOGGER = CAS::LoggerWrapper.new
  
  # Allows authentication through a CAS server.
  # The precondition for this filter to work is that you have an
  # authentication infrastructure. As such, this is for the enterprise
  # rather than small shops.
  #
  # To use CAS::Filter for authentication, add something like this to
  # your environment:
  # 
  #   CAS::Filter.server_name = "yourapplication.server.name"
  #   CAS::Filter.cas_base_url = "https://cas.company.com
  #   
  # The filter will try to use the standard CAS page locations based on this URL.
  # Or you can explicitly specify the individual URLs:
  #
  #   CAS::Filter.server_name = "yourapplication.server.name"
  #   CAS::Filter.login_url = "https://cas.company.com/login"
  #   CAS::Filter.validate_url = "https://cas.company.com/proxyValidate"
  #
  # It is of course possible to use different configurations in development, test
  # and production by placing the configuration in the appropriate environments file.
  #
  # To add CAS protection to a Rails controller:
  # 
  #   before_filter CAS::Filter
  #   
  # All of the standard Rails filter qualifiers can also be used. For example:
  # 
  #   before_filter CAS::Filter, :only => [:admin, :private]
  #
  # By default CAS::Filter saves the logged in user in session[:casfilteruser] but
  # that name can be changed by setting CAS::Filter.session_username
  # The username is also available from the request by
  # 
  #   request.username
  #   
  # This wrapping of the request can be disabled by
  # 
  #   CAS::Filter.wrap_request = false
  # 
  # Proxying is also possible. Please see the README for examples.
  #
  class Filter
    @@login_url = "https://localhost/login"
    @@logout_url = nil
    @@validate_url = "https://localhost/proxyValidate"
    @@server_name = "localhost"
    @@renew = false
    @@session_username = :casfilteruser
    @@query_string = {}
    @@fake = nil
    @@pgt = nil
    cattr_accessor :query_string
    cattr_accessor :login_url, :validate_url, :service_url, :server_name, :wrap_request, :session_username
    class_inheritable_accessor :gateway, :renew
    cattr_accessor :proxy_url, :proxy_callback_url, :proxy_retrieval_url
    @@authorized_proxies = []
    cattr_accessor :authorized_proxies

    # gatewaying is disabled by default -- use GatewayFilter if you want gatewaying
    self.gateway = false

    class << self
    
      # Retrieves the Logger used by the filter
      def logger
        CAS::LOGGER
      end
      # Sets the Logger used by the filter
      def logger=(val)
        CAS::LOGGER.set_logger(val)
      end
  
      alias :log :logger
      alias :log= :logger=
  
      # Builds the internal logout URL. The current @@logout_url value will
      # be used if it is set. Otherwise we will try to figure it out based
      # on the @@login_url.
      def create_logout_url
        if !@@logout_url && @@login_url =~ %r{^(.+?)/[^/]*$}
          @@logout_url = "#{$1}/logout"
        end
        logger.debug "Created logout url: #{@@logout_url}"
      end
      
      # Returns the logout URL for the given controller.
      # This method calls create_logout_url if no logout url has yet
      # been created or set.
      def logout_url(controller)
        create_logout_url unless @@logout_url
        url = redirect_url(controller,@@logout_url)
        logger.debug "Logout url is: #{url}"
        url
      end
      
      # Explicitly sets the logout URL.
      def logout_url=(url)
        @@logout_url = url
        logger.debug "Initialized logout url to: #{url}"
      end
      
      # Sets the base CAS url. The login_url, validate_url, and proxy_url
      # are automagically built on top of this.
      def cas_base_url=(url)
        url.gsub!(/\/$/, '')
        CAS::Filter.login_url = "#{url}/login"
        CAS::Filter.validate_url = "#{url}/proxyValidate"
        CAS::Filter.proxy_url = "#{url}/proxy"
        logger.debug "Initialized CAS base url to: #{url}"
      end
      
      # Returns the current @@fake value.
      # This is used for debugging. See <tt>fake=</tt> and <tt>filter_f</tt>.
      def fake
        @@fake
      end
      
      # Enables or disables the fake filter.
      # This is used in debugging.
      #
      # The argument can have one of the following values:
      #
      # :failure :: The fake filter will always fail.
      # :param :: The fake filter will use the 'username' request param to set 
      #           the username.
      # Proc :: The fake filter will execute the given proc to determine the 
      #         username. The current controller will be fed to the Proc as an
      #         argument.
      # nil :: Disables the fake filter and enables the real filter.
      def fake=(val)
        if val.nil?
          alias :filter :filter_r
        else
          alias :filter :filter_f
          logger.warn "Will use fake filter"
          end
          @@fake = val
        end
  
      # This is the fake filter method. It is aliased as 'filter'
      # when the fake filter is enabled. See <tt>fake=</tt>.
      def filter_f(controller)
          logger.break
          logger.warn "Using fake CAS filter"
        username = @@fake
        if :failure == @@fake
          return false
        elsif :param == @@fake
          username = controller.params['username']
        elsif Proc === @@fake
          username = @@fake.call(controller)
        end
        logger.info("The username set by the fake filter is: #{username}")
        controller.session[@@session_username] = username
        return true
      end
      
      # This is the real filter method. It is alias as 'filter'
      # by default (when the fake filter is disabled).
      #
      # The filter method behaves like a standard Rails filter, taking
      # the current controller as an argument (in order to access the current
      # request params, the session, etc.). The method returns true
      # when authentication is successful, false otherwise. Generally,
      # before returning false the filter will send a HTTP redirect back to the 
      # CAS server.
      def filter_r(controller)
        logger.break
        logger.info("Using real CAS filter in controller: #{controller}")
        
        session_receipt = controller.session[:casfilterreceipt]
        session_ticket = controller.session[:caslastticket]
        ticket = controller.params[:ticket]
  
        is_valid = false
        
        if controller.session[:casfiltergateway]
          log.debug "Coming back from gatewayed request to CAS server..."
          did_gateway = true
          controller.session[:casfiltergateway] = false
        else
          log.debug "This request is not gatewayed."
        end
        
        if ticket and (!session_ticket or session_ticket != ticket)
          log.info "A ticket parameter was given in the URI: #{ticket} and "+
            (!session_ticket ? "there is no previous ticket for this session" : 
                "the ticket is different than the previous ticket, which was #{session_ticket}")
        
          receipt = get_receipt_for_ticket(ticket, controller)
          
          if receipt && validate_receipt(receipt)
            logger.info("Receipt for ticket request #{ticket} is valid, belongs to user #{receipt.user_name}, and will be stored in the session.")
            controller.session[:casfilterreceipt] = receipt
            controller.session[:caslastticket] = ticket
            controller.session[@@session_username] = receipt.user_name
            
            if receipt.pgt_iou
              logger.info("Receipt has a proxy-granting ticket IOU. Attempting to retrieve the proxy-granting ticket...")
              pgt = retrieve_pgt(receipt)
              if pgt
                log.debug("Got PGT #{pgt} for PGT IOU #{receipt.pgt_iou}. This will be stored in the session.")
                controller.session[:casfilterpgt] = pgt
              else
                log.error("Failed to retrieve a PGT for PGT IOU #{receipt.pgt_iou}!")
              end
            end
            
            is_valid = true
          else
            if receipt
              log.warn "Receipt was invalid for ticket #{ticket}!"
            else
              log.warn "get_receipt_for_ticket() for ticket #{ticket} did not return a receipt!"
            end
          end
          
        elsif session_receipt
        
          log.info "Validating receipt from the session because " + 
            (ticket ? "the given ticket #{ticket} is the same as the old ticket" : "there was no ticket given in the URI") + "."
          log.debug "The session receipt is: #{session_receipt}"
          
          is_valid = validate_receipt(session_receipt)
          
          if is_valid
            log.info "The session receipt is VALID"
          else 
            log.warn "The session receipt is NOT VALID!"
          end
          
        else
          
          log.info "No ticket was given and we do not have a receipt in the session."
        
          
          raise CASException, "Can't redirect without login url" unless @@login_url
          
          if did_gateway
            log.info "We gatewayed and came back without authentication."
            if self.gateway
              log.info "This filter is configured to allow gatewaying, so we will permit the user to continue without authentication."
              return true
            else
              log.warn "This filter is NOT configured to allow gatewaying, yet this request was gatewayed. Something is not right!"
            end
          elsif self.gateway
            log.debug "We did not gateway, so we will notify the filter that the next request is being gatewayed by setting sesson[:casfiltergateway} to true"
            controller.session[:casfiltergateway] = true
          end
          
        end
        
        if is_valid
          logger.info "This request is successfully CAS authenticated for user #{controller.session[@@session_username]}!"
          return true
        else
          controller.session[:service] = service_url(controller)
          logger.info "This request is NOT CAS authenticated, so we will redirect to the login page at: #{redirect_url(controller)}"
            controller.send :redirect_to, redirect_url(controller) and return false
        end
      end
      alias :filter :filter_r
        
      # Requests a proxy ticket from the CAS server and returns it as a ProxyTicketRequest object.
      #
      # Note that the ProxyTicketRequest object is returned regardless of whether the request
      # is successful. You should check the returned object's proxy_ticket field to find out
      # whether the request resulted in a valid proxy ticket.
      def request_proxy_ticket(target_service, pgt)
        r = ProxyTicketRequest.new
        r.proxy_url = @@proxy_url
        r.target_service = target_service
        r.pgt = pgt
  
        # FIXME: Why is this here? The only way it would get raised is if the supplied pgt was nil/false? This might be a vestige...
        raise CAS::ProxyGrantingNotAvailable, "Cannot request a proxy ticket for service #{r.target_service} because no proxy granting ticket (PGT) has been set." unless r.pgt
        
        logger.info("Requesting proxy ticket for service: #{r.target_service} with PGT #{pgt}")
        r.request
        
        if r.proxy_ticket
          logger.info("Got proxy ticket #{r.proxy_ticket} for service #{r.target_service}")
        else
          logger.warn("Did not receive a proxy ticket for service #{r.target_service}! Reason: #{r.error_code}: #{r.error_message}")
        end
        
        return r
      end
    end
    
    
    
    private
    
      # Retrieves a proxy granting ticket corresponding to the given receipt's
      # proxy granting ticket IOU from the proxy callback server.
      #
      # Returns a CAS::ProxyGrantingTicket object.
      def self.retrieve_pgt(receipt)
        retrieve_url = "#{@@proxy_retrieval_url}?pgtIou=#{receipt.pgt_iou}"
                
        logger.debug("Will attempt to retrieve the PGT from: #{retrieve_url}")
        
        pgt = CAS::ServiceTicketValidator.retrieve(retrieve_url)
        
        logger.info("Retrieved the PGT: #{pgt}")
        
        return pgt
      end
    
      # Returns true if the given CAS::Receipt is valid; false wotherwise.
      def self.validate_receipt(receipt)
        logger.info "Checking that the receipt is valid and coherent..."
        
        if not receipt
          logger.info "No receipt given, so the receipt is invalid"
          return false
        elsif @@renew && !receipt.primary_authentication?
          logger.info "The filter is configured to force primary authentication (i.e. the renew options is set to true), but the receipt was not generated by primary authentication so we consider it invalid"
          return false
        end
        
        if receipt.proxied?    
          logger.info "The receipt is proxied by proxying service: #{receipt.proxying_service}"
          
          if @@authorized_proxies and !@@authorized_proxies.empty?
            logger.debug "Authorized proxies are: #{@@authorized_proxies.inspect}"
            
            if !@@authorized_proxies.include? receipt.proxying_service
              logger.warn "Receipt was proxied by #{receipt_proxying_service} but this proxying service is not in the list of authorized proxies. The receipt is therefore invalid."
              return false
            else
              logger.info "Receipt is proxied by a valid proxying service."
            end
          else
            logger.info "No authorized proxies set, so any proxy will be considered valid"
          end
        else
          logger.info "Receipt is not proxied"
        end
        
        return true
      end
  
      # Fetches a CAS::Receipt for the given service or proxy ticket
      # and returns it.
      #
      # Takes the current controller as the second argument in order to
      # guess the current service URL when it is not explicitly set for
      # the filter.
      def self.get_receipt_for_ticket(ticket, controller)
        logger.info "Getting receipt for ticket '#{ticket}'"
        pv = ProxyTicketValidator.new
        pv.validate_url = @@validate_url
        pv.service_ticket = ticket
        pv.service = controller.session[:service] || service_url(controller)
        pv.renew = @@renew
        pv.proxy_callback_url = @@proxy_callback_url
        receipt = nil
        logger.debug "ProxyTicketValidator is: #{pv.inspect}"
        begin
          receipt = Receipt.new(pv)
        rescue AuthenticationException => e
          logger.warn("Getting a receipt for the ProxyTicketValidator threw an exception: #{e}")
        rescue  MalformedServerResponseException => e
          logger.error("CAS Server returned malformed response:\n\n#{e}")
          raise e
        end
        logger.debug "Receipt is: #{receipt.inspect}"
        receipt
      end
      
      # Returns the service URL for the current service.
      #
      # This will return the @@service_url if it has been explicitly
      # set; otherwise it will try to guess the service URL based
      # on the given controller parameters (see <tt>guess_service()</tt>).
      def self.service_url(controller)
        unclean = @@service_url || guess_service(controller)
        clean = remove_ticket_from_service_uri(unclean)
        logger.debug("Service URI without ticket is: #{clean}")
        clean
      end
      
      # Returns the URL to the login page of the CAS server with
      # additional parameters like 'renew', and 'gateway' tacked
      # on as appropriate. The <tt>url</tt> parameter can be used
      # to use something other than the login url as the base.
      #
      # FIXME: this method is really poorly named :(
      def self.redirect_url(controller,url=@@login_url)
        "#{url}?service=#{CGI.escape(service_url(controller))}" + 
          ((@@renew)? "&renew=true":"") + 
          ((gateway)? "&gateway=true":"") + 
          ((@@query_string.blank?)? "" : "&" +
          (@@query_string.collect { |k,v| "#{k}=#{v}"}.join("&")))
      end
      
      # Tries to figure out the current service URL. 
      #
      # This is used when the @@service_url has not been explicitly set. 
      # The guessed URL (generally the current URL stripped of some 
      # CAS-specific parameters) is fed to the CAS server so that the
      # server knows where to redirect back after authentication.
      #
      # Also see <tt>redirect_url</tt>.
      def self.guess_service(controller)
        logger.info "Guessing service based on params: #{controller.params.inspect}"
        
        # we're assuming that controller.params[:service] is url-encoded!
        if controller.params and controller.params.include? :service
          service = controller.params[:service]
          logger.info "We have a :service param, so we will URI-decode it and use this as the service: #{controller.params[:service]}"
          return service
        end
        
        req = controller.request
        
        if controller.params
          parms = controller.params.dup
        else
          parms = {}
        end
        
        parms.delete("ticket")
        service = controller.url_for(parms)
        
        logger.info "Guessed service is: #{service}"
        
        return service
      end
      
      # URI-encodes the 
      def self.escape_service_uri(uri)
        # FIXME: Why aren't we just using  CGi.escape?
        URI.encode(uri, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]", false, 'U').freeze)
      end
      
      # The service URI should never have a ticket parameter, but we use this to remove
      # any parameters named "ticket" just in case, as having a "ticket" parameter in the
      # service URI will generally cause an infinite redirection loop.
      def self.remove_ticket_from_service_uri(uri)
        uri.gsub(/ticket=[^&$]*&?/, '')
      end
  end
  
  # The GatewayFilter is identical to the normal Filter, but has the gateway 
  # option set to true by default. This makes it easier to use in cases where 
  # authentication is optional.
  #
  # For example, say your 'index' view is accessible by authenticated and 
  # unauthenticated users, but you want some additional content shown for 
  # authenticated users. You can use the GatewayFilter to check if the user is 
  # already authenticated with CAS and provide them with a service ticket for 
  # the new service. If they are not already authenticated, then they will be 
  # allowed to see the 'index' view without being asked for a login.
  #
  # To achieve this in a Rails controller, you should set up your filters as follows:
  #
  #   before_filter CAS::Filter, :except => [:index]  
  #   before_filter CAS::GatewayFilter, :only => [:index]
  #
  # Note that you cannot use the 'renew' option with the GatewayFilter since the 
  # 'gateway' and 'renew' options have roughly opposite meanings -- 'renew' forces
  # re-authentication, while 'gateway' makes authentication optional.
  class GatewayFilter < Filter
    self.gateway = true
    self.renew = false
  end
  
  class ProxyGrantingNotAvailable < Exception
  end
end

class ActionController::AbstractRequest
  def username
    session[CAS::Filter.session_username]
  end
end
