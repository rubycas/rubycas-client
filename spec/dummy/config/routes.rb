if defined? Dummy
  Dummy::Application.routes.draw do
   # match ':controller(/:action(/:id))(.:format)'
  end
else
  ActionController::Routing::Routes.draw do |map|
    #set up our routes.... again
  end
end
