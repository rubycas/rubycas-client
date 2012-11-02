# -*- encoding : utf-8 -*-
class ModifySessions < ActiveRecord::Migration
  def self.up
    #column added to sessions table by rubycas-client
    add_column :sessions, :service_ticket, :string
    add_index :sessions, :service_ticket
  end

  def self.down
    remove_index :sessions, :service_ticket
    remove_column :sessions, :service_ticket
  end
end
