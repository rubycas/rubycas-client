require 'uri'
require 'logger'

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
  # To add CAS protection to a controller:
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
    cattr_accessor :login_url, :validate_url, :service_url, :server_name, :renew, :wrap_request, :gateway, :session_username
    cattr_accessor :proxy_url, :proxy_callback_url, :proxy_retrieval_url
    @@authorized_proxies = []
    cattr_accessor :authorized_proxies


    class << self
      # Retrieves the current Logger instance
      def logger
        CAS::LOGGER
      end
      def logger=(val)
        CAS::LOGGER.set_logger(val)
      end

      alias :log :logger
      alias :log= :logger=

      def create_logout_url
        if !@@logout_url && @@login_url =~ %r{^(.+?)/[^/]*$}
          @@logout_url = "#{$1}/logout"
        end
        logger.info "Created logout url: #{@@logout_url}"
      end
      
      def logout_url(controller)
        create_logout_url unless @@logout_url
        url = redirect_url(controller,@@logout_url)
        logger.info "Logout url is: #{url}"
        url
      end
      
      def logout_url=(url)
        @@logout_url = url
        logger.info "Set logout url to: #{url}"
      end
      
      def cas_base_url=(url)
        CAS::Filter.login_url = "#{url}/login"
        CAS::Filter.validate_url = "#{url}/proxyValidate"
        CAS::Filter.proxy_url = "#{url}/proxy"
        logger.info "Set CAS base url to: #{url}"
      end
        
      def fake
        @@fake
      end
      
      def fake=(val)
        if val.nil?
          alias :filter :filter_r
          logger.info "Will use real filter"
        else
          alias :filter :filter_f
          logger.warn "Will use fake filter"
        end
        @@fake = val
      end

      def filter_f(controller)
        logger.warn("Using fake CAS filter")
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
      
      def filter_r(controller)
        logger.info("Using real CAS filter in controller: #{controller}")
        receipt = controller.session[:casfilterreceipt]

        valid = false
        if receipt
          log.info "Validating receipt from the session"
          log.debug "The session receipt is: #{receipt}"
          valid = validate_receipt(receipt)
          if valid
            log.info "The session receipt is VALID"
          else 
            log.warn "The session receipt is NOT VALID!"
          end
        else
          log.info "There is no receipt stored in the session"
          reqticket = controller.params["ticket"]
          if reqticket
            log.info "We have a ticket: #{reqticket}"
            
            # We temporarily allow ActionController requests to be handled concurrently.
            # Otherwise proxy granting ticket callbacks from CAS wouldn't work, since
            # the Rails server would be deadlocked while it waits for the CAS server to validate
            # the ticket, and the CAS server waits for the Rails server to receive the PGT callback.
            # 
            # Note that since the allow_concurrency option is undocumented and considered
            # experimental, what we're doing here may cause unforseen problems (or more likely,
            # it just won't work). Beware!
            ActionController::Base.allow_concurrency = true
            receipt = authenticated_user(reqticket,controller)
            ActionController::Base.allow_concurrency = false
            
            if receipt && validate_receipt(receipt)
              logger.info("Receipt for ticket request #{reqticket} is valid and will be stored in the session under :casfilterreceipt.")
              controller.session[:casfilterreceipt] = receipt
              controller.session[@@session_username] = receipt.user_name
              
              if receipt.pgt_iou
                logger.info("Receipt has a proxy-granting ticket IOU. Attempting to retrieve the proxy-granting ticket...")
                # I've briefly allowed concurrency here in an attempt to alllow the Rails app act as its own proxy
                # callback. Unfortunately this probably doesn't work, and you will almost certainly have to run
                # the CAS callback controller on a separate Rails app.
                ActionController::Base.allow_concurrency = true
                retrieve_url = "#{@@proxy_retrieval_url}?pgtIou=#{receipt.pgt_iou}"
                
                logger.debug("Will attempt to retrieve the PGT from: #{retrieve_url}")
                
                pgt = CAS::ServiceTicketValidator.retrieve(retrieve_url)
                
                logger.info("Retrieved the PGT: #{pgt}")
                
                controller.session[:casfilterpgt] = pgt
                
                ActionController::Base.allow_concurrency = false
              end
              
              valid = true
            end
          else
            log.info "We do not have a ticket."
            
            did_gateway = controller.session[:casfiltergateway]
            raise CASException, "Can't redirect without login url" if !@@login_url
            
            if did_gateway
              if controller.session[@@session_username]
                log.info "We gatewayed and have a username stored in the session. The gateway was therefore successful."
                valid = true
              else
                log.debug "We gatewayed but do not have a username stored in the session, so we will keep session[:casfiltergateway] true"
                controller.session[:casfiltergateway] = true
              end
            else
              log.info "We did not gateway, so we will notify the filter that the next request is being gatewayed by setting sesson[:casfiltergateway} to true"
              controller.session[:casfiltergateway] = true
            end
          end
        end
        
        if valid
          logger.info "This request is successfully CAS authenticated!"
          return true
        else
          logger.info "This request is NOT CAS authenticated, so we will redirect to the login page at: #{redirect_url(controller)}"
          controller.send :redirect_to, redirect_url(controller) and return false
        end
      end
      alias :filter :filter_r
      
      
      def request_proxy_ticket(target_service, pgt)
        r = ProxyTicketRequest.new
        r.proxy_url = @@proxy_url
        # FIXME: target_service is not being URI encoded here, because the JA-SIG CAS server doesn't seem to be URI-decoding it on
        #         the other end. This means that service URIs with ampersands (&) will probably fail. Need to look into why the JA-SIG
        #         server might not be URI-decoding this value.
        r.target_service = target_service
        r.pgt = pgt

        raise "Cannot request a proxy ticket for service #{r.target_service} because no proxy granting ticket (PGT) has been set." unless r.pgt
        
        logger.info("Requesting proxy ticket for service: #{r.target_service} with PGT #{pgt}")
        r.request
        
        if r.proxy_ticket
          logger.info("Got proxy ticket #{r.proxy_ticket} for service #{r.target_service}")
        else
          logger.warn("Did not receive a proxy ticket for service #{r.target_service}!")
        end
        
        return r
      end
    end
    
    private
    def self.validate_receipt(receipt)
      logger.info "Checking that the  receipt is valid and coherent."
      
      if not receipt
        logger.info "No receipt given, so the receipt is invalid"
        return false
      elsif @@renew && !receipt.primary_authentication?
        logger.info "The filter is configured to force primary authentication (i.e. the renew options is set to true), but the receipt was not generated by primary authentication so we consider it invalid"
        return false
      end
      
      if receipt.proxied?      
        if @@authorized_proxies and !@@authorized_proxies.empty?
          logger.debug "Authorized proxies are: #{@@authorized_proxies.inspect}"
          
            logger.info "Receipt is proxied by proxying service: #{receipt.proxying_service}"
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

    def self.authenticated_user(ticket, controller)
      logger.info "Getting receipt for ticket '#{ticket}'"
      pv = ProxyTicketValidator.new
      pv.validate_url = @@validate_url
      pv.service_ticket = ticket
      pv.service = service_url(controller)
      pv.renew = @@renew
      pv.proxy_callback_url = @@proxy_callback_url
      receipt = nil
      logger.debug "ProxyTicketValidator is: #{pv.inspect}"
      begin
        receipt = Receipt.new(pv)
      rescue AuthenticationException => e
        logger.warn("Getting a receipt for the ProxyTicketValidator threw an exception: #{e}")
      end
      logger.debug "Receipt is: #{receipt.inspect}"
      receipt
    end
    
    def self.service_url(controller)
      before = @@service_url || guess_service(controller)
      logger.debug("Service URI before encoding is: #{before}")
      after = escape_service_uri(remove_ticket_from_service_uri(before))
      logger.debug("Service URI after encoding is: #{after}")
      after
    end
    
    def self.redirect_url(controller,url=@@login_url)
      "#{url}?service=#{service_url(controller)}" + ((@@renew)? "&renew=true":"") + ((@@gateway)? "&gateway=true":"") + ((@@query_string.nil?)? "" : "&"+(@@query_string.collect { |k,v| "#{k}=#{v}"}.join("&")))
    end
    
    def self.guess_service(controller)
      logger.info "Guessing service based on params: #{controller.params.inspect}"
    
      
      # we're assuming that controller.params[:service] is url-encoded!
      if controller.params.include? :service
        logger.info "We have a :service param, so we will use this as the service: #{controller.params[:service]}"
        return controller.params[:service] 
      end
      
      req = controller.request
      parms = controller.params.dup
      parms.delete("ticket")
      query = (parms.collect {|key, val| "#{key}=#{val}"}).join("&")
      query = "?" + query unless query.empty?
      
      service = "#{req.protocol}#{@@server_name}#{req.request_uri.split(/\?/)[0]}#{query}"
      
      logger.info "Guessed service is: #{service}"
      
      return service
    end
    
    def self.escape_service_uri(uri)
      URI.encode(uri, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]", false, 'U').freeze)
    end
    
    # The service URI should never have a ticket parameter, but we use this to remove
    # any parameters named "ticket" just in case, as having a "ticket" parameter in the
    # service URI will generally cause an infinite redirection loop.
    def self.remove_ticket_from_service_uri(uri)
      uri.gsub(/&?ticket=[^&$]*/, '')
    end
  end
end

class ActionController::AbstractRequest
  def username
    session[CAS::Filter.session_username]
  end
end
