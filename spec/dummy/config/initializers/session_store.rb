# Be sure to restart your server when you modify this file.

if defined? Dummy
  Dummy::Application.config.session_store :cookie_store, :key => '_dummy_session'
else
  ActionController::Base.session = {
    :key         => '_dummy_session',
    :secret      => '4de43a1f7e9886181978771e9280d7cb3ce295dffd7b8447040fd1ac66825cbe04675128d6897924d1607df13039e11ab167dad35c30c4d15cbf4de56459e701'
  }
end

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Dummy::Application.config.session_store :active_record_store
