# -*- encoding : utf-8 -*-
class AddPgtious < ActiveRecord::Migration
  def self.up
    # pgtious table
    create_table :cas_pgtious do |t|
      t.string :pgt_iou, :null => false
      t.string :pgt_id, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :cas_pgtious
  end
end
