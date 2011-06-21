module CASClient
  # Represents a CAS service ticket.
  class ServiceTicket
    attr_reader :ticket, :service, :renew
    attr_accessor :user, :extra_attributes, :pgt_iou, :success, :failure_code, :failure_message
    
    def initialize(ticket, service, renew = false)
      @ticket = ticket
      @service = service
      @renew = renew
    end
    
    def is_valid?
      success
    end
    
    def has_been_validated?
      not user.nil?
    end
  end
  
  # Represents a CAS proxy ticket.
  class ProxyTicket < ServiceTicket
  end
  
  class ProxyGrantingTicket
    attr_reader :ticket, :iou
    
    def initialize(ticket, iou)
      @ticket = ticket
      @iou = iou
    end
    
    def to_s
      ticket
    end
  end
end