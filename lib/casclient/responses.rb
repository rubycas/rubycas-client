module CASClient
  # Represents a response from the CAS server to a 'validate' request
  # (i.e. when validating servie/proxy tickets).
  class ValidationResponse
    attr_reader :xml, :parsetime
    attr_reader :protocol, :user, :pgt, :proxies, :extra_attributes
    attr_reader :failure_code, :failure_message
    
    def initialize(raw_text)
      parse(raw_text)
    end
    
    def parse(raw_text)
      raise BadResponseException, 
        "Cas response is empty/blank." if raw_text.blank?
      @parsetime = Time.now
      begin
        if raw_text =~ /^(yes|no)\n(.*?)\n$/m
          @protocol = 1.0
          @valid = $~[1] == 'yes'
          @user = $~[2]
          return
        end
        
        doc = REXML::Document.new(raw_text)
      rescue REXML::ParseException => e
        raise BadResponseException, 
          "MALFORMED CAS RESPONSE:\n#{str.inspect}\n\nEXCEPTION:\n#{e}"
      end
      
      unless doc.elements && doc.elements["cas:serviceResponse"]
        raise BadResponseException, 
          "This does not appear to be a valid CAS response (missing cas:serviceResponse root element)!\nXML DOC:\n#{doc.to_s}"
      end
      
      # if we got this far then we've got a valid XML response, so we're doing CAS 2.0
      @protocol = 2.0
      
      @xml = doc.elements["cas:serviceResponse"].elements[1]
      
      if is_success?
        @user = @xml.elements["cas:user"].text.strip if @xml.elements["cas:user"]
        @pgt =  @xml.elements["cas:proxyGrantingTicket"].text.strip if @xml.elements["cas:proxyGrantingTicket"]
        
        proxy_els = @xml.elements.to_a('//cas:authenticationSuccess/cas:proxies/cas:proxy')
        if proxy_els.size > 0
          @proxies = []
          proxy_els.each do |el|
            @proxies << el.text
          end
        end
        
        @extra_attributes = {}
        @xml.elements.to_a('//cas:authenticationSuccess/*').each do |el|
          @extra_attributes.merge!(Hash.from_xml(el.to_s)) unless el.prefix == 'cas'
        end
      elsif is_failure?
        @failure_code = @xml.elements['//cas:authenticationFailure'].attributes['code']
        @failure_message = @xml.elements['//cas:authenticationFailure'].text.strip
      else
        # this should never happen, since the response should already have been recognized as invalid
        raise BadResponseException, "BAD CAS RESPONSE:\n#{str.inspect}\n\nXML DOC:\n#{doc.inspect}"
      end
      
    end
    
    def is_success?
      @valid == true || (protocol > 1.0 && @xml.name == "authenticationSuccess")
    end
    
    def is_failure?
      @valid == false || (protocol > 1.0 && @xml.name == "authenticationFailure" )
    end
  end
  
  # Represents a response from the CAS server to a login request (i.e. when submitting a username/password).
  class LoginResponse
    attr_reader :tgt, :ticket, :service_redirect_url
    attr_reader :failure_message
    
    def initialize(http_response = nil)
      parse_http_response(http_response) if http_response
    end
    
    def parse_http_response(http_response)
      header = http_response.to_hash
      
      # FIXME: this regexp might be incorrect...
      if header['set-cookie'] && 
          header['set-cookie'].first && 
          header['set-cookie'].first =~ /tgt=([^&]+);/
        @tgt = $~[1]
      end
    
      location = header['location'].first if header['location'] && header['location'].first
      if location =~ /ticket=([^&]+)/
        @ticket = $~[1]
      end
      
      if !http_response.kind_of?(Net::HTTPSuccess) || ticket.blank?
        @failure = true
        # Try to extract the error message -- this only works with RubyCAS-Server.
        # For other servers we just return the entire response body (i.e. the whole error page).
        body = http_response.body
        if body =~ /<div class="messagebox mistake">(.*?)<\/div>/m
          @failure_message = $~[1].strip
        else
          @failure_message = body
        end
      end
      
      @service_redirect_url = location
    end
    
    def is_success?
      !@failure && !ticket.blank?
    end
    
    def is_failure?
      @failure == true
    end
  end
  
  class BadResponseException < CASException
  end
end