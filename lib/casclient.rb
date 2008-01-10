require 'uri'
require 'cgi'
require 'net/https'
require 'rexml/document'

require 'active_support'

module CASClient
  # The client brokers all HTTP transactions with the CAS server.
  class Client
    attr_reader :login_url, :validate_url, :protocol
    
    def configure(conf)
      raise ArgumentError, "Missing :login_url parameter!" unless conf[:login_url]
      raise ArgumentError, "Missing :validate_url parameter!" unless conf[:validate_url]
      
      @login_url    = conf[:login_url]
      @validate_url = conf[:validate_url]
      
      @session_username = conf[:session_username_key] || :casfilteruser
    end
    
    def validate_service_ticket(st)
      uri = URI.parse(@validate_url)
      h = query_to_hash(uri.query)
      h['service'] = st.service
      h['ticket'] = st.ticket
      h['renew'] = 1 if st.renew
      uri.query = hash_to_query(h)
      
      st.response = fetch_cas_response(uri)
      
      return st
    end
    alias validate_proxy_ticket validate_service_ticket
    
    private
    # Fetches a CAS Response from the given URI.
    def fetch_cas_response(uri)
      uri = URI.parse(uri) unless uri.kind_of? URI
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      raw_res = https.start do |conn|
        conn.get("#{uri.path}?#{uri.query}").body.strip
      end
      
      #TODO: check to make sure that response code is 200 and handle errors otherwise
      
      Response.new(raw_res.body)
    end
  end
  
  # Represents a CAS service ticket.
  class ServiceTicket
    attr_reader :ticket, :service, :renew
    attr_accessor :response
    
    def initialize(ticket, service, renew = false)
      @ticket = ticket
      @service = service
      @renew = renew
    end
    
    def is_valid?
      response.is_success?
    end
    
    def has_been_validated?
      not response.nil?
    end
  end
  
  # Represents a CAS proxy ticket.
  class ProxyTicket < ServiceTicket
    attr_reader :pgt_url
    
    def initialize(ticket, service, pgt_url, renew = false)
      @ticket = ticket
      @service = service
      @pgt_url = pgt_url
      @renew = renew
    end
  end
  
  # Represents a response from a CAS server.
  class Response
    attr_reader :xml, :parsetime
    attr_reader :protocol, :user, :pgt, :proxies, :extra_attributes
    
    def initialize(raw_text)
      parse(raw_text)
    end
    
    def parse(raw_text)
      @parsetime = Time.now
      begin
        doc = REXML::Document.new(raw_text)
      rescue REXML::ParseException => e
        if raw_text =~ /^(yes|no)\n(.*?)\n$/m
          @protocol = 1.0
          @valid = $~[1] == 'yes'
          @user = $~[2]
          return
        end
        raise BadResponseException, "MALFORMED CAS RESPONSE:\n#{str.inspect}\n\nEXCEPTION:\n#{e}"
      end
      
      unless doc.elements && doc.elements["cas:serviceResponse"]
        raise BadResponseException, "BAD CAS RESPONSE:\n#{str.inspect}\n\nXML DOC:\n#{doc.inspect}"
      end
      
      # if we got this far then we've got a valid XML response, so we're doing CAS 2.0
      @protocol = 2.0
      
      @xml = CASResponse.new(doc.elements["cas:serviceResponse"].elements[1])
      
      if is_success?
        @user = @xml.elements["cas:user"].text.strip if @xml.elements["cas:user"]
        @pgt =  @xml.elements["cas:proxyGrantingTicket"] if @xml.elements["cas:proxyGrantingTicket"]
        
        @xml.elements.to_a('//cas:authenticationSuccess/cas:proxies/cas:proxy').each do |el|
          @other_attributes.merge!(Hash.from_xml(el.to_s)) unless el.prefix == 'cas'
        end
        
        @extra_attributes = {}
        @xml.elements.to_a('//cas:authenticationSuccess/*').each do |el|
          @extra_attributes.merge!(Hash.from_xml(el.to_s)) unless el.prefix == 'cas'
        end
      elsif is_failure?
        
      else
        # this should never happen!
        raise BadResponseException, "BAD CAS RESPONSE:\n#{str.inspect}\n\nXML DOC:\n#{doc.inspect}"
      end
      
    end
    
    def is_success?
      @valid == true || @xml.name == "authenticationSuccess"
    end
    
    def is_failure?
      @valid == false || @xml.name = "authenticationFailure" 
    end
    
    private
    def query_to_hash(query)
      CGI.parse(query)
    end
      
    def hash_to_query(hash)
      pairs = []
      hash.each do |k, vals|
        vals = [vals] unless vals.kind_of Array
        v.each {|v| paris << "#{CGI.escape(k)}=#{CGI.escape(v)}"}
      end
      pairs.join("&")
    end
  end
  
  class CASException < Exception
  end
  
  class BadResponseException < CASException
  end
end