require 'active_record'

module ActiveRecordHelpers

  class << self
    def setup_active_record
      config_file = File.open("spec/database.yml")
      db_config = HashWithIndifferentAccess.new(YAML.load(config_file))
      ActiveRecord::Base.establish_connection(db_config[(RUBY_PLATFORM == "java") ? :testjruby : :test])
      ActiveRecord::Migration.verbose = false
      RubyCasTables.migrate(:up)
    end

    def teardown_active_record
      ActiveRecord::Migration.verbose = false
      RubyCasTables.migrate(:down)
    end
  end

  class RubyCasTables < ActiveRecord::Migration
    def self.up
      #default rails sessions table
      create_table :sessions do |t|
        t.string :session_id, :null => false
        t.text :data
        t.timestamps
      end
      add_index :sessions, :session_id
      add_index :sessions, :updated_at

      #column added to sessions table by rubycas-client
      add_column :sessions, :service_ticket, :string
      add_index :sessions, :service_ticket

      # pgtious table
      create_table :cas_pgtious do |t|
        t.string :pgt_iou, :null => false
        t.string :pgt_id, :null => false
        t.timestamps
      end
    end

    def self.down
      drop_table :sessions
      drop_table :cas_pgtious
    end
  end
end
