module CASClient
  # The client brokers all HTTP transactions with the CAS server.
  class Client
    attr_reader :cas_base_url 
    attr_reader :log, :session_username_key, :session_extra_attributes_key
    attr_writer :login_url, :validate_url, :proxy_url, :logout_url
    
    def initialize(conf = nil)
      configure(conf) if conf
    end
    
    def configure(conf)
      raise ArgumentError, "Missing :cas_base_url parameter!" unless conf[:cas_base_url]
      
      @cas_url      = conf[:cas_base_url].gsub(/\/$/, '')       
      
      @login_url    = conf[:login_url]
      @validate_url = conf[:validate_url]
      @logout_url   = conf[:logout_url]
      @proxy_url    = conf[:proxy_url]
      
      @session_username_key         = conf[:session_username_key] || :cas_user
      @session_extra_attributes_key = conf[:session_extra_attributes_key] || :cas_extra_attributes
      
      @log = CASClient::Logger.new
      @log.set_real_logger(conf[:logger]) if conf[:logger]
    end
    
    def login_url
      @login_url || (@cas_base_url + "/login")
    end
    
    def validate_url
      @validate_url || (@cas_base_url + "/proxyValidate")
    end
    
    def logout_url
      @logout_url || (@cas_base_url + "/logout")
    end
    
    def proxy_url
      @proxy_url || (@login_url + "/proxy")
    end
    
    def validate_service_ticket(st)
      uri = URI.parse(@validate_url)
      h = uri.query ? query_to_hash(uri.query) : {}
      h['service'] = st.service
      h['ticket'] = st.ticket
      h['renew'] = 1 if st.renew
      uri.query = hash_to_query(h)
      
      st.response = request_cas_response(uri)
      
      return st
    end
    alias validate_proxy_ticket validate_service_ticket
    
    # Requests a login using the given credentials for the given service; 
    # returns a LoginResponse object.
    def login_to_service(credentials, service)
      lt = request_login_ticket
      
      data = credentials.merge(
        :lt => lt,
        :service => service 
      )
      
      res = submit_data_to_cas(@login_url, data)
      CASClient::LoginResponse.new(res)
    end
  
    # Requests a login ticket from the CAS server for use in a login request;
    # returns a LoginTicket object.
    #
    # This only works with RubyCAS-Server, since obtaining login
    # tickets in this manner is not part of the official CAS spec.
    def request_login_ticket
      uri = URI.parse(@login_url+'Ticket')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      res = https.post(uri.path, ';')
      
      raise CASException, res.body unless res.kind_of? Net::HTTPSuccess
      
      res.body.strip
    end
    
    # Requests a proxy ticket from the CAS server for the given service
    # using the given pgt (proxy granting ticket); returns a ProxyTicket 
    # object.
    #
    # The pgt required to request a proxy ticket is obtained as part of
    # a ValidationResponse.
    def request_proxy_ticket(pgt, target_service)
      uri = URI.parse(@login_url+'Ticket')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      res = https.post(uri.path, ';')
      
      raise CASException, res.body unless res.kind_of? Net::HTTPSuccess
      
      res.body.strip
    end
    
    private
    # Fetches a CAS ValidationResponse from the given URI.
    def request_cas_response(uri)
      uri = URI.parse(uri) unless uri.kind_of? URI
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      raw_res = https.start do |conn|
        conn.get("#{uri.path}?#{uri.query}")
      end
      
      #TODO: check to make sure that response code is 200 and handle errors otherwise
      
      ValidationResponse.new(raw_res.body)
    end
    
    # Submits some data to the given URI and returns a Net::HTTPResponse.
    def submit_data_to_cas(uri, data)
      uri = URI.parse(uri) unless uri.kind_of? URI
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data, ';')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = (uri.scheme == 'https')
      https.start {|conn| conn.request(req) }
    end
    
    def query_to_hash(query)
      CGI.parse(query)
    end
      
    def hash_to_query(hash)
      pairs = []
      hash.each do |k, vals|
        vals = [vals] unless vals.kind_of? Array
        vals.each {|v| pairs << "#{CGI.escape(k)}=#{CGI.escape(v)}"}
      end
      pairs.join("&")
    end
  end
end