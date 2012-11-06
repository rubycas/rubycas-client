require 'action_pack'

module ActionControllerHelpers

  DEFAULT_ENV_OPTS = {
    :method => 'GET',
    :params => 'ticket=some_ticket'
  }
  def build_controller_instance(env_opts={})
    controller = UnfilteredController.new

    request_env = Rack::MockRequest.env_for('/unfiltered', DEFAULT_ENV_OPTS.merge(env_opts))
    request = build_request_for(request_env)

    if is_rails2?
      controller.session = {}
      controller.params = request.params
    end

    controller.request = request

    final_setup_on(controller)

    return controller
  end

  def build_request_for(request_env)
    if is_rails2?
      request = ActionController::TestRequest.new(request_env)
      # because an empty string returns false for #present?
      # we have to ensure there is a valid value for 'REQUEST_URI'
      uri = "http://test.host"
      query_string = request.env['QUERY_STRING']
      uri << (query_string ? "?#{query_string}" : '')
      request.env['REQUEST_URI'] = uri
      request.query_parameters = request.GET
    else
      request = ActionDispatch::TestRequest.new(request_env)
    end

    request.path_parameters = {
      :controller => 'unfiltered',
      :action => 'index'
    }.with_indifferent_access

    request
  end

  def final_setup_on(controller)
    if is_rails2?
      controller.send(:initialize_current_url)
    end
  end

protected
  def is_rails2?
    @_is_rails2 ||= Rails.version =~ /^2.3/
  end

  def ticketless_url(controller)
    params = controller.params.dup
    params.delete(:ticket)
    controller.url_for(params)
  end
end
