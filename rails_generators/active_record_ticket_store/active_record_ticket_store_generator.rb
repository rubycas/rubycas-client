class ActiveRecordTicketStoreGenerator < Rails::Generator::NamedBase

  def initialize(runtime_args, runtime_options = {})
    runtime_args << 'create_active_record_ticket_store' if runtime_args.empty?
    super
  end

  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate',
        :assigns => { :session_table_name => default_session_table_name, :pgtiou_table_name => default_pgtiou_table_name }
      m.readme "README"
    end
  end

  protected
  def banner
    "Usage: #{$0} #{spec.name} [CreateActiveRecordTicketStore] [options]"
  end

  def default_session_table_name
    ActiveRecord::Base.pluralize_table_names ? 'session'.pluralize : 'session'
  end

  def default_pgtiou_table_name
    ActiveRecord::Base.pluralize_table_names ? 'cas_pgtiou'.pluralize : 'cas_pgtiou'
  end

end
