require 'net/https'
require 'rexml/document'

module CAS
  class CASException < Exception
  end
  class AuthenticationException < CASException
  end
  class ValidationException < CASException
  end
  class MalformedServerResponseException < CASException
  end

  class Receipt
    attr_accessor :validate_url, :pgt_iou, :primary_authentication, :proxy_callback_url, :proxy_list, :user_name

    def primary_authentication?
      primary_authentication
    end

    def initialize(ptv)
      if !ptv.successful_authentication?
        begin
          ptv.validate
        rescue ValidationException=>vald
          raise AuthenticationException, "Unable to validate ProxyTicketValidator [#{ptv}] [#{vald}]"
        end
        raise AuthenticationException, "Unable to validate ProxyTicketValidator because of no success with validation[#{ptv}]" unless ptv.successful_authentication?
      end
      self.validate_url = ptv.validate_url
      self.pgt_iou = ptv.pgt_iou
      self.user_name = ptv.user
      self.proxy_callback_url = ptv.proxy_callback_url
      self.proxy_list = ptv.proxy_list
      self.primary_authentication = ptv.renewed?
      raise AuthenticationException, "Validation of [#{ptv}] did not result in an internally consistent Receipt" unless validate
    end

    def proxied?
      !proxy_list.empty?
    end

    def proxying_service
      proxy_list.first
    end

    def to_s
      "[#{super} - userName=[#{user_name}] validateUrl=[#{validate_url}] proxyCallbackUrl=[#{proxy_callback_url}] pgtIou=[#{pgt_iou}] proxyList=[#{proxy_list}]"
    end

    def validate
      user_name &&
        validate_url &&
        proxy_list &&
        !(primary_authentication? && !proxy_list.empty?) # May not be both primary authenitication and proxied.
    end
  end

  class AbstractCASResponse
    attr_reader :error_code, :error_message, :successful_authentication
  
    def self.retrieve(uri_str)
      prs = URI.parse(uri_str)
      https = Net::HTTP.new(prs.host,prs.port)
      https.use_ssl = true
      https.start { |conn|
        # TODO: make sure that HTTP status code in the response is 200... maybe throw exception if is 500?
        conn.get("#{prs.path}?#{prs.query}").body.strip
      }
    end
    
    protected
    def parse_unsuccessful(elm)
      @error_message = elm.text.strip
      @error_code = elm.attributes["code"].strip
      @successful_authentication = false
    end

    def parse(str)
      begin
        doc = REXML::Document.new str
      rescue REXML::ParseException
        raise MalformedServerResponseException, "BAD RESPONSE FROM CAS SERVER:\n#{str}"
      end
      
      unless doc.elements && doc.elements["cas:serviceResponse"]
        raise MalformedServerResponseException, "BAD RESPONSE FROM CAS SERVER:\n#{str}"
      end
      
      resp = doc.elements["cas:serviceResponse"].elements[1]
      
      if successful_response? resp
        parse_successful(resp)
      else
        parse_unsuccessful(resp)
      end
    end
  end
  
  class ServiceTicketValidator < AbstractCASResponse
    attr_accessor :validate_url, :proxy_callback_url, :renew, :service_ticket, :service
    attr_reader   :pgt_iou, :user, :entire_response

    def renewed?
      renew
    end

    def successful_authentication?
      successful_authentication
    end

    def validate
      raise ValidationException, "must set validation URL and ticket" if validate_url.nil? || service_ticket.nil?
      clear!
      @attempted_authentication = true
      url_building = "#{validate_url}#{(url_building =~ /\?/)?'&':'?'}service=#{CGI.escape(service)}&ticket=#{service_ticket}"
      url_building += "&pgtUrl=#{proxy_callback_url}" if proxy_callback_url
      url_building += "&renew=true" if renew
      @@entire_response = ServiceTicketValidator.retrieve url_building
      parse @@entire_response
    end

    def clear!
      @user = @pgt_iou = @error_message = nil
      @successful_authentication = @attempted_authentication = false
    end

    def to_s
      "[#{super} - validateUrl=[#{validate_url}] proxyCallbackUrl=[#{proxy_callback_url}] ticket=[#{service_ticket}] service=[#{service} pgtIou=[#{pgt_iou}] user=[#{user}] errorCode=[#{error_message}] errorMessage=[#{error_message}] renew=[#{renew}] entireResponse=[#{entire_response}]]"
    end
    
    protected
    def parse_successful(elm)
#      puts "successful"
      @user = elm.elements["cas:user"] && elm.elements["cas:user"].text.strip
#      puts "user: #{@user}"
      @pgt_iou = elm.elements["cas:proxyGrantingTicket"] && elm.elements["cas:proxyGrantingTicket"].text.strip
#      puts "pgt_iou: #{@pgt_iou}"
      @successful_authentication = true
    end
    
    def successful_response?(resp)
      resp.name == "authenticationSuccess"
    end
  end

  class ProxyTicketValidator < ServiceTicketValidator
    attr_reader :proxy_list
    @@response_prefix = "proxy"

    def initialize
      super
      @proxy_list = []
    end

    def clear!
      super
      @proxy_list = []
    end

    protected
    def parse_successful(elm)
      super(elm)
      
      proxies = elm.elements["cas:proxies"]
      if proxies
        proxies.elements.each("cas:proxy") { |prox|
          @proxy_list ||= []
          @proxy_list << prox.text.strip
        }
      end
    end
  end

  class ProxyTicketRequest < AbstractCASResponse
    attr_accessor :proxy_url, :target_service, :pgt
    attr_reader :proxy_ticket
  
    def request
      url_building = "#{proxy_url}#{(url_building =~ /\?/)?'&':'?'}pgt=#{pgt}&targetService=#{CGI.escape(target_service)}"
      @@entire_response = ServiceTicketValidator.retrieve url_building
      parse @@entire_response
    end
    
    protected
    def parse_successful(elm)
      @proxy_ticket = elm.elements["cas:proxyTicket"] && elm.elements["cas:proxyTicket"].text.strip
    end
    
    def successful_response?(resp)
      resp.name == "proxySuccess"
    end
  end
end
