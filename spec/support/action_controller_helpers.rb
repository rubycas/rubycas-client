require 'action_pack'

module ActionControllerHelpers

  def mock_controller_with_session(request = nil, session={})

    query_parameters = {:ticket => "bogusticket", :renew => false}
    parameters = query_parameters.dup

    #TODO this really need to be replaced with a "real" rails controller
    request ||= mock_post_request
    request.stub(:query_parameters) {query_parameters}
    request.stub(:path_parameters) {{}}
    controller = double("Controller")
    controller.stub(:session) {session}
    controller.stub(:request) {request}
    controller.stub(:url_for) {"bogusurl"}
    controller.stub(:query_parameters) {query_parameters}
    controller.stub(:path_parameters) {{}}
    controller.stub(:parameters) {parameters}
    controller.stub(:params) {parameters}
    controller
  end

  def mock_post_request
      mock_request = double("request")
      mock_request.stub(:post?) {true}
      mock_request.stub(:session_options) { Hash.new }
      mock_request.stub(:headers) { Hash.new }
      mock_request
  end
end
