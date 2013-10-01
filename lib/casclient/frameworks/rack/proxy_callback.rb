# Rack middleware that responds to proxy generating ticket callbacks from the
# CAS server and allows for retrieval of those PGTs elsewhere.
module CasProxy
  class Callback

    def call(env)
      req = Rack::Request.new(env)
      case env["PATH_INFO"]

      # Receives a proxy granting ticket from the CAS server and stores it in the database.
      # Note that this action should ALWAYS be called via https, otherwise you have a gaping security hole.
      # In fact, the JA-SIG implementation of the CAS server will refuse to send PGTs to non-https URLs.
      when "/cas_proxy_callback/receive_pgt" # Rack map removes the prefix. matches the Rails routing
        pgtIou = req.params['pgtIou']

        # CAS Protocol spec says that the argument should be called 'pgt', but the JA-SIG CAS server seems to use pgtId.
        # To accomodate this, we check for both parameters, although 'pgt' takes precedence over 'pgtId'.
        pgtId = req.params['pgt'] || req.params['pgtId']

        # We need to render a response with HTTP status code 200 when no pgtIou/pgtId is specified because CAS seems first
        # call the action without any parameters (maybe to check if the server responds correctly)
        return [200, {'Content-Type' => 'text/plain'}, ["Okay, the server is up, but please specify a pgtIou and pgtId."]] unless pgtIou and pgtId

        CASClient::Frameworks::Rack::ProxyFilter.client.ticket_store.save_pgt_iou(pgtIou, pgtId)

        [200, {'Content-Type' => 'text/plain'}, ["PGT received. Thank you!"]]
      end

    end

  end
end
