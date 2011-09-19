module CASClient
  module Tickets
    module Storage
      class AbstractTicketStore

        attr_accessor :log
        @log = CASClient::LoggerWrapper.new

        def process_single_sign_out(si)

          session_id, session = get_session_for_service_ticket(si)
          if session
            session.destroy
            log.debug("Destroyed #{session.inspect} for session #{session_id.inspect} corresponding to service ticket #{si.inspect}.")
          else
            log.debug("Data for session #{session_id.inspect} was not found. It may have already been cleared by a local CAS logout request.")
          end

          if session_id
            log.info("Single-sign-out for service ticket #{session_id.inspect} completed successfuly.")
          else
            log.debug("No session id found for CAS ticket #{si}")
          end
        end

        def get_session_for_service_ticket(st)
          session_id = read_service_session_lookup(si)
          if session_id
            session = ActiveRecord::SessionStore::Session.find_by_session_id(session_id)
          else
            log.warn("Couldn't destroy session with SessionIndex #{si} because no corresponding session id could be looked up.")
          end
          [session_id, session]
        end

        def store_service_session_lookup(st, controller)
          raise 'Implement this in a subclass!'
        end

        def cleanup_service_session_lookup(st)
          raise 'Implement this in a subclass!'
        end

        def save_pgt_iou(pgt_iou, pgt)
          raise 'Implement this in a subclass!'
        end

        def retrieve_pgt(pgt_iou)
          raise 'Implement this in a subclass!'
        end

        protected
        def read_service_session_lookup(st)
          raise 'Implement this in a subclass!'
        end
      end

      # A Ticket Store that keeps it's tickets in a directory on the local filesystem.
      # Service tickets are stored under tmp/sessions by default
      # and Proxy Granting Tickets and their IOUs are stored in tmp/cas_pgt.pstore
      # This Ticket Store works fine for small sites but will most likely have
      # concurrency problems under heavy load. It also requires that all your
      # worker processes have access to a shared file system.
      #
      # This ticket store takes the following config parameters
      # :storage_dir - The directory to store data in. Defaults to RAILS_ROOT/tmp
      # :service_session_lookup_dir - The directory to store Service Ticket/Session ID files in. Defaults to :storage_dir/sessions
      # :pgt_store_path - The location to store the pgt PStore file. Defaults to :storage_dir/cas_pgt.pstore
      class LocalDirTicketStore < AbstractTicketStore
        require 'pstore'

        DEFAULT_TMP_DIR = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/tmp" : "#{Dir.pwd}/tmp"

        def initialize(config={})
          config ||= {}
          @tmp_dir = config[:storage_dir] || DEFAULT_TMP_DIR
          @service_session_lookup_dir = config[:service_session_lookup_dir] || "#{@tmp_dir}/sessions"
          @pgt_store_path = config[:pgt_store_path] || "#{@tmp_dir}/cas_pgt.pstore"
        end

        # Creates a file in tmp/sessions linking a SessionTicket
        # with the local Rails session id. The file is named
        # cas_sess.<session ticket> and its text contents is the corresponding
        # Rails session id.
        # Returns the filename of the lookup file created.
        def store_service_session_lookup(st, controller)
          raise CASException, "No service_ticket specified." unless st
          raise CASException, "No controller specified." unless controller

          sid = controller.request.session_options[:id] || controller.session.session_id

          st = st.ticket if st.kind_of? ServiceTicket
          f = File.new(filename_of_service_session_lookup(st), 'w')
          f.write(sid)
          f.close
          return f.path
        end

        # Returns the local Rails session ID corresponding to the given
        # ServiceTicket. This is done by reading the contents of the
        # cas_sess.<session ticket> file created in a prior call to 
        # #store_service_session_lookup.
        def read_service_session_lookup(st)
          raise CASException, "No service_ticket specified." unless st

          st = st.ticket if st.kind_of? ServiceTicket
          ssl_filename = filename_of_service_session_lookup(st)
          return File.exists?(ssl_filename) && IO.read(ssl_filename)
        end

        # Removes a stored relationship between a ServiceTicket and a local
        # Rails session id. This should be called when the session is being
        # closed.
        #
        # See #store_service_session_lookup.
        def cleanup_service_session_lookup(st)
          raise CASException, "No service_ticket specified." unless st

          st = st.ticket if st.kind_of? ServiceTicket
          ssl_filename = filename_of_service_session_lookup(st)
          File.delete(ssl_filename) if File.exists?(ssl_filename)
        end

        def save_pgt_iou(pgt_iou, pgt)
          # TODO: pstore contents should probably be encrypted...
          pstore = open_pstore

          pstore.transaction do
            pstore[pgt_iou] = pgt
          end
        end

        def retrieve_pgt(pgt_iou)
          raise CASException, "No pgt_iou specified. Cannot retrieve the pgt." unless pgt_iou

          pstore = open_pstore

          pgt = nil
          pstore.transaction do
            pgt = pstore[pgt_iou]
          end

          raise CASException, "Invalid pgt_iou specified. Perhaps this pgt has already been retrieved?" unless pgt

          # TODO: need to periodically clean the storage, otherwise it will just keep growing
          pstore.transaction do
            pstore.delete pgt_iou
          end

          pgt
        end

        private

        # Returns the path and filename of the service session lookup file.
        def filename_of_service_session_lookup(st)
          st = st.ticket if st.kind_of? ServiceTicket
          return "#{@service_session_lookup_dir}/cas_sess.#{st}"
        end

        def open_pstore
          PStore.new(@pgt_store_path)
        end
      end
    end
  end
end
