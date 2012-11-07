if defined? Dummy
  Dummy::Application.routes.draw do
    match 'unfiltered' => 'unfiltered#index', :as => :unfiltered
    # match ':controller(/:action(/:id))(.:format)'
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.unfiltered '/unfiltered', :controller => 'unfiltered', :action => 'index'
  end
end
