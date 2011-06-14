class <%= class_name %> < ActiveRecord::Migration
  def self.up
    add_column :<%= session_table_name %>, :service_ticket, :string

    add_index :<%= session_table_name %>, :service_ticket
    
    create_table :<%= pgtiou_table_name %> do |t|
      t.string :pgt_iou, :null => false
      t.string :pgt_id, :null => false
      t.timestamps
    end

    add_index :<%= pgtiou_table_name %>, :pgt_iou, :unique => true
  end

  def self.down
    drop_table :<%= pgtiou_table_name %>

    remove_index :<%= session_table_name %>, :service_ticket

    remove_column :<%= session_table_name %>, :service_ticket
  end
end

