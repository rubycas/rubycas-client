require 'redis'

module CASClient
  module Tickets
    module Storage

      # A Ticket Store that keeps its ticket data in redis
      
      class RedisStore < AbstractTicketStore
        
        def initialize(config={})
          config ||= {} 
          @namespace = "cas_#{config[:env]}"
          @redis = Redis.new({ host: config[:host], port: config[:port] })
        end
        
        def redis
          @redis
        end
        
        def path_for(key)
          @namespace + key
        end

        def store_service_session_lookup(st, controller)
          raise CASException, "No service_ticket specified." unless st
          raise CASException, "No controller specified." unless controller

          st = st.ticket if st.kind_of? ServiceTicket
          redis.set(path_for(st), dump(controller.session.id))
        end

        def read_service_session_lookup(st)
          raise CASException, "No service_ticket specified." unless st
          st = st.ticket if st.kind_of? ServiceTicket
          load(redis.get(path_for(st)))
        end

        def cleanup_service_session_lookup(st)
          #no cleanup needed for this ticket store
          #we still raise the exception for API compliance
          raise CASException, "No service_ticket specified." unless st
        end

        def save_pgt_iou(pgt_iou, pgt)
          raise CASClient::CASException.new("Invalid pgt_iou") if pgt_iou.nil?
          raise CASClient::CASException.new("Invalid pgt") if pgt.nil?
          redis.set(path_for(pgt_iou), dump(pgt) )
        end

        def retrieve_pgt(pgt_iou)
          raise CASException, "No pgt_iou specified. Cannot retrieve the pgt." unless pgt_iou
          pgt_id = load(redis.get(path_for(pgt_iou)))
          raise CASException, "Invalid pgt_iou specified. Perhaps this pgt has already been retrieved?" unless pgt_id
          redis.set(path_for(pgt_iou), dump(nil))
          pgt_id
        end

        def dump(obj)
          Marshal.dump(obj)
        end

        def load(obj)
          Marshal.load(obj)
        end

      end

      REDIS_TICKET_STORE = RedisStore

    end
  end
end
