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
        logger.info "Created logout-url: #{@@logout_url}"
      end
      
      def logout_url(controller)
        create_logout_url unless @@logout_url
        url = redirect_url(controller,@@logout_url)
        logger.info "Using logout-url #{url}"
        url
      end
      
      def logout_url=(val)
        @@logout_url = val
      end
      
      def cas_base_url=(url)
        CAS::Filter.login_url = "#{url}/login"
        CAS::Filter.validate_url = "#{url}/proxyValidate"
        CAS::Filter.proxy_url = "#{url}/proxy"
      end
        
      def fake
        @@fake
      end
      
      def fake=(val)
        if val.nil?
          alias :filter :filter_r
        else
          alias :filter :filter_f
        end
        @@fake = val
      end

      def filter_f(controller)
        logger.debug("entering fake cas filter")
        username = @@fake
        if :failure == @@fake
          return false
        elsif :param == @@fake
          username = controller.params['username']
        elsif Proc === @@fake
          username = @@fake.call(controller)
        end
        logger.debug("our username is: #{username}")
        controller.session[@@session_username] = username
        return true
      end
      
      def filter_r(controller)
        logger.debug("\n\n==================================================================")
        logger.debug("filter of controller: #{controller}")
        receipt = controller.session[:casfilterreceipt]
        logger.info("receipt: #{receipt}")
        valid = false
        if receipt
          valid = validate_receipt(receipt)
          logger.info("valid receipt?: #{valid}")
        else
          reqticket = controller.params["ticket"]
          logger.info("ticket: #{reqticket}")
          if reqticket
            # We temporarily allow ActionController requests to be handled concurrently.
            # Otherwise proxy granting ticket callbacks from CAS wouldn't work, since
            # the Rails server would be deadlocked while it waits for the CAS server to validate
            # the ticket, and the CAS server waits for the Rails server to receive the PGT callback.
            # Note that since the allow_concurrency option is undocumented and considered
            # experimental, what we're doing here may cause unforseen problems. Beware!
            ActionController::Base.allow_concurrency = true
            receipt = authenticated_user(reqticket,controller)
            ActionController::Base.allow_concurrency = false
            
            logger.info("new receipt: #{receipt}")
            logger.info("validate_receipt: " + validate_receipt(receipt).to_s)
            if receipt && validate_receipt(receipt)
              controller.session[:casfilterreceipt] = receipt
              controller.session[@@session_username] = receipt.user_name
              
              if receipt.pgt_iou
                ActionController::Base.allow_concurrency = true
                retrieve_url = "#{@@proxy_retrieval_url}?pgtIou=#{receipt.pgt_iou}"
                logger.info("retrieving pgt from: #{retrieve_url}")
                controller.session[:casfilterpgt] = CAS::ServiceTicketValidator.retrieve(retrieve_url)
                ActionController::Base.allow_concurrency = false
              end
              
              valid = true
            end
          else
            did_gateway = controller.session[:casfiltergateway]
            raise CASException, "Can't redirect without login url" if !@@login_url
            if did_gateway
              if controller.session[@@session_username]
                valid = true
              else
                controller.session[:casfiltergateway] = true
              end
            else
              controller.session[:casfiltergateway] = true
            end
          end
        end
        logger.info("will send redirect #{redirect_url(controller)}") if !valid
        controller.send :redirect_to,redirect_url(controller) if !valid
        return valid
      end
      alias :filter :filter_r
      
      
      def request_proxy_ticket(target_service, pgt)
        r = ProxyTicketRequest.new
        r.proxy_url = @@proxy_url
        r.target_service = escape_service_uri(target_service)
        r.pgt = pgt

        raise "Cannot request a proxy ticket for service #{r.target_service} because no proxy granting ticket (PGT) has been set." unless r.pgt
        
        logger.info("requesting proxy ticket for service #{r.target_service} with pgt #{pgt}")
        r.request
        
        if r.proxy_ticket
          logger.info("got proxy ticket #{r.proxy_ticket} for service #{r.target_service}")
        else
          logger.warn("did not receive a proxy ticket for service #{r.target_service}!")
        end
        
        return r
      end
    end
    
    private
    def self.validate_receipt(receipt)       
        if receipt
          logger.debug "authorized proxies: #{@@authorized_proxies.inspect}"
          logger.debug "proxying service: #{receipt.proxying_service.inspect}"
        end
        
        valid = receipt && !(@@renew && !receipt.primary_authentication?)
        
        if @@authorized_proxies and !@@authorized_proxies.empty?
          valid = valid && !(receipt.proxied? && !@@authorized_proxies.include?(receipt.proxying_service)) 
        end
        
        return valid
    end

    def self.authenticated_user(tick, controller)
      pv = ProxyTicketValidator.new
      pv.validate_url = @@validate_url
      pv.service_ticket = tick
      pv.service = service_url(controller)
      pv.renew = @@renew
      pv.proxy_callback_url = @@proxy_callback_url
      receipt = nil
      logger.debug("pv: #{pv.inspect}")
      begin
        receipt = Receipt.new(pv)
      rescue AuthenticationException=>auth
        logger.warn("filter: had an authentication-exception #{auth}")
      end
      receipt
    end
    
    def self.service_url(controller)
      before = @@service_url || guess_service(controller)
      logger.debug("service url before escape: #{before}")
      after = escape_service_uri(remove_ticket_from_service_uri(before))
      logger.debug("service url after escape: #{after}")
      after
    end
    
    def self.redirect_url(controller,url=@@login_url)
      "#{url}?service=#{service_url(controller)}" + ((@@renew)? "&renew=true":"") + ((@@gateway)? "&gateway=true":"") + ((@@query_string.nil?)? "" : "&"+(@@query_string.collect { |k,v| "#{k}=#{v}"}.join("&")))
    end
    
    def self.guess_service(controller)
      log.debug("guessing service based on params #{controller.params.inspect}")
    
      # we're assuming that controller.params[:service] is url-encoded!
      return controller.params[:service] if controller.params.include? :service
      
      req = controller.request
      parms = controller.params.dup
      parms.delete("ticket")
      query = (parms.collect {|key, val| "#{key}=#{val}"}).join("&")
      query = "?" + query unless query.empty?
      "#{req.protocol}#{@@server_name}#{req.request_uri.split(/\?/)[0]}#{query}"
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
