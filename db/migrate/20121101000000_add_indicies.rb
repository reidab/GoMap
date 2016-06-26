class AddIndicies < ActiveRecord::Migration
  def change
    add_index :log, :name
    add_index :trips, :car_name
  end
end
