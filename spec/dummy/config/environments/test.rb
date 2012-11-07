# Since there was a massive shift in how initialization is done for  Rails 3.x
# we have to do some hackety hackety hacks here to make everything line up
if defined? RAILS_GEM_VERSION
  eval(File.read(File.expand_path('../real_test.rb',__FILE__)))
else
  Dummy::Application.configure do
    eval(File.read(File.expand_path('../real_test.rb',__FILE__)))
  end
end
