require 'casclient/tickets/storage'

class LocalHashTicketStore < CASClient::Tickets::Storage::AbstractTicketStore

  attr_accessor :st_hash
  attr_accessor :pgt_hash

  def store_service_session_lookup(st, controller)
    raise CASClient::CASException, "No service_ticket specified." if st.nil?
    raise CASClient::CASException, "No controller specified." if controller.nil?
    session_id = session_id_from_controller(controller)
    st = st.ticket if st.kind_of? CASClient::ServiceTicket
    st_hash[st] = session_id
  end

  def read_service_session_lookup(st)
    raise CASClient::CASException, "No service_ticket specified." if st.nil?
    st = st.ticket if st.kind_of? CASClient::ServiceTicket
    st_hash[st]
  end

  def cleanup_service_session_lookup(st)
    raise CASClient::CASException, "No service_ticket specified." if st.nil?
    st = st.ticket if st.kind_of? CASClient::ServiceTicket
    st_hash.delete(st)
  end

  def save_pgt_iou(pgt_iou, pgt)
    raise CASClient::CASException.new("Invalid pgt_iou") if pgt_iou.nil?
    raise CASClient::CASException.new("Invalid pgt") if pgt.nil?
    pgt_hash[pgt_iou] = pgt
  end

  def retrieve_pgt(pgt_iou)
    pgt = pgt_hash.delete(pgt_iou)
    raise CASClient::CASException.new("Invalid pgt_iou") if pgt.nil?
    pgt
  end

  def pgt_hash
    @pgt_hash ||= {}
  end

  def st_hash
    @pgt_hash ||= {}
  end

end
