class CreateTrips < ActiveRecord::Migration
  def change
    create_table :trips do |t|
      t.belongs_to :start, :end
      t.text :directions
    end
  end
end

