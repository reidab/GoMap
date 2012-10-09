require_relative '../../environment.rb'

class StoreTimesAndCarNameOnTrip < ActiveRecord::Migration
  def up
    add_column :trips, :car_name, :string
    add_column :trips, :start_time, :datetime
    add_column :trips, :end_time, :datetime
    add_column :trips, :estimated_start_time, :datetime
    add_column :trips, :created_at, :datetime
    add_column :trips, :updated_at, :datetime

    say_with_time "Populating creation times" do
      Trip.find_each do |trip|
        next unless trip && trip.end
        trip.created_at = trip.end.created_at
        trip.save!
      end
    end
  end

  def down
  end
end
