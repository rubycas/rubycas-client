module CASClient
  module XmlResponse
    attr_reader :xml, :parse_datetime
    attr_reader :failure_code, :failure_message

    def check_and_parse_xml(raw_xml)
      begin
        doc = REXML::Document.new(raw_xml, :raw => :all)
      rescue REXML::ParseException => e
        raise BadResponseException, 
          "MALFORMED CAS RESPONSE:\n#{raw_xml.inspect}\n\nEXCEPTION:\n#{e}"
      end

      unless doc.elements && doc.elements["cas:serviceResponse"]
        raise BadResponseException, 
          "This does not appear to be a valid CAS response (missing cas:serviceResponse root element)!\nXML DOC:\n#{doc.to_s}"
      end

      return doc.elements["cas:serviceResponse"].elements[1]
    end

    def to_s
      xml.to_s
    end
  end

  # Represents a response from the CAS server to a 'validate' request
  # (i.e. after validating a service/proxy ticket).
  class ValidationResponse
    include XmlResponse

    attr_reader :protocol, :user, :pgt_iou, :proxies, :extra_attributes

    def initialize(raw_text, options={})
      parse(raw_text, options)
    end

    def parse(raw_text, options)
      raise BadResponseException, 
        "CAS response is empty/blank." if raw_text.blank?
      @parse_datetime = Time.now
      if raw_text =~ /^(yes|no)\n(.*?)\n$/m
        @protocol = 1.0
        @valid = $~[1] == 'yes'
        @user = $~[2]
        return
      end

      @xml = check_and_parse_xml(raw_text)

      # if we got this far then we've got a valid XML response, so we're doing CAS 2.0
      @protocol = 2.0

      if is_success?
        cas_user = @xml.elements["cas:user"]
        @user = cas_user.text.strip if cas_user
        @pgt_iou =  @xml.elements["cas:proxyGrantingTicket"].text.strip if @xml.elements["cas:proxyGrantingTicket"]

        proxy_els = @xml.elements.to_a('//cas:authenticationSuccess/cas:proxies/cas:proxy')
        if proxy_els.size > 0
          @proxies = []
          proxy_els.each do |el|
            @proxies << el.text
          end
        end

        @extra_attributes = {}
        @xml.elements.to_a('//cas:authenticationSuccess/cas:attributes/* | //cas:authenticationSuccess/*[local-name() != \'proxies\' and local-name() != \'proxyGrantingTicket\' and local-name() != \'user\' and local-name() != \'attributes\']').each do |el|
          inner_text = el.cdatas.length > 0 ? el.cdatas.join('') : el.text
          name = el.name
          unless (attrs = el.attributes).empty?
            name       = attrs['name']
            inner_text = attrs['value']
          end
          @extra_attributes.merge! name => inner_text
        end

        # unserialize extra attributes
        @extra_attributes.each do |k, v|
          @extra_attributes[k] = parse_extra_attribute_value(v, options[:encode_extra_attributes_as])
        end
      elsif is_failure?
        @failure_code = @xml.elements['//cas:authenticationFailure'].attributes['code']
        @failure_message = @xml.elements['//cas:authenticationFailure'].text.strip
      else
        # this should never happen, since the response should already have been recognized as invalid
        raise BadResponseException, "BAD CAS RESPONSE:\n#{raw_text.inspect}\n\nXML DOC:\n#{doc.inspect}"
      end
    end

    def parse_extra_attribute_value(value, encode_extra_attributes_as)
      attr_value = if value.blank?
         nil
       elsif !encode_extra_attributes_as
         begin
           YAML.load(value)
         rescue ArgumentError => e
           raise ArgumentError, "Error parsing extra attribute with value #{value} as YAML: #{e}"
         end
       else
         if encode_extra_attributes_as == :json
           begin
             JSON.parse(value)
           rescue JSON::ParserError
             value
           end
         elsif encode_extra_attributes_as == :raw
           value
         else
           YAML.load(value)
         end
       end

      unless attr_value.kind_of?(Enumerable) || attr_value.kind_of?(TrueClass) || attr_value.kind_of?(FalseClass) || attr_value.nil?
        attr_value.to_s
      else
        attr_value
      end
    end

    def is_success?
      (instance_variable_defined?(:@valid) &&  @valid) || (protocol > 1.0 && xml.name == "authenticationSuccess")
    end

    def is_failure?
      (instance_variable_defined?(:@valid) && !@valid) || (protocol > 1.0 && xml.name == "authenticationFailure" )
    end
  end

  # Represents a response from the CAS server to a proxy ticket request 
  # (i.e. after requesting a proxy ticket).
  class ProxyResponse
    include XmlResponse

    attr_reader :proxy_ticket

    def initialize(raw_text, options={})
      parse(raw_text)
    end

    def parse(raw_text)
      raise BadResponseException, 
        "CAS response is empty/blank." if raw_text.blank?
      @parse_datetime = Time.now

      @xml = check_and_parse_xml(raw_text)

      if is_success?
        @proxy_ticket = @xml.elements["cas:proxyTicket"].text.strip if @xml.elements["cas:proxyTicket"]
      elsif is_failure?
        @failure_code = @xml.elements['//cas:proxyFailure'].attributes['code']
        @failure_message = @xml.elements['//cas:proxyFailure'].text.strip
      else
        # this should never happen, since the response should already have been recognized as invalid
        raise BadResponseException, "BAD CAS RESPONSE:\n#{raw_text.inspect}\n\nXML DOC:\n#{doc.inspect}"
      end

    end

    def is_success?
      xml.name == "proxySuccess"
    end

    def is_failure?
      xml.name == "proxyFailure"
    end
  end

  # Represents a response from the CAS server to a login request 
  # (i.e. after submitting a username/password).
  class LoginResponse
    attr_reader :tgt, :ticket, :service_redirect_url
    attr_reader :failure_message

    def initialize(http_response = nil, options={})
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

      if not ((http_response.kind_of?(Net::HTTPSuccess) || http_response.kind_of?(Net::HTTPFound)) && @ticket.present?)
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
