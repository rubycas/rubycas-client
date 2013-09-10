module CASClient
  module Frameworks
    module Rack

      class Response
        def initialize(user = nil, extra_attributes = nil, *errors)
          @user, @extra_attributes, @errors = user, extra_attributes, errors
        end

        def valid?
          @errors.empty?
        end

        def to_s
          "User: #{@user}, Attributes: [#{@extra_attributes}], Valid?: #{valid?}, Errors: #{@errors}"
        end

        def error_messages
          @errors.join(", ")
        end
      end


      # A simplified filter that only manages Proxy requests
      class ProxyFilter

        @@config = nil
        @@client = nil
        @@log = nil

        class << self
          def filter(req)
            raise "Cannot use the CASClient filter because it has not yet been configured." if config.nil?
            begin
              if st = read_ticket(req)
                client.validate_service_ticket(st)

                if st.is_valid? # st.extra_attributes
                  if st.pgt_iou
                    if client.retrieve_proxy_granting_ticket(st.pgt_iou)
                      return Response.new(st.user.dup, HashWithIndifferentAccess.new(st.extra_attributes))
                    end

                    log.error("Failed to retrieve a PGT for PGT IOU #{st.pgt_iou}!")
                  end
                end
              end
            rescue OpenSSL::SSL::SSLError => err
              Response.new(nil, nil, "OpenSSL::SSL::SSLError #{err}")
            end

            Response.new(nil, nil, "unauthorized!")
          end

          def configure(config)
            @@config = config
            @@config[:logger] ||= ::App.logger
            @@client = CASClient::Client.new(config)
            @@log = client.log
          end

          def config
            @@config
          end

          def log
            @@log
          end

          def client
            @@client
          end

          private

          def read_ticket(req)
            log.error("#{self.class.name} Read Ticket: #{req.params[:ticket]}")
            ticket = req.params[:ticket]
            return nil unless ticket
            log.debug("Request contains ticket #{ticket.inspect}.")
            if ticket =~ /^PT-/
              ProxyTicket.new(ticket, config[:service_url], req.params[:renew])
            else
              ServiceTicket.new(ticket, config[:service_url], req.params[:renew])
            end
          end

        end
      end

    end
  end
end
