class CreateLog < ActiveRecord::Migration
  def change
    create_table :log do |t|
      t.string :address, :engine_type, :exterior_condition, :interior_condition, :name, :vin
      t.integer :fuel
      t.boolean :charging
      t.column :latitude, :decimal, scale: 6, precision: 10
      t.column :longitude, :decimal, scale: 6, precision: 10
      t.column :altitude, :decimal, scale: 6, precision: 10
      t.timestamps
    end
  end
end
