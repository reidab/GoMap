module GoMap
  class Cron
    def self.run(location, consumer_key)

      puts ""
      puts "=" * 80
      puts "Starting run at #{Time.now}"

      response = HTTParty.get("http://www.car2go.com/api/v2.1/vehicles", 
                              query: { loc: location,
                                       oauth_consumer_key: consumer_key,
                                       format: 'json' })
      cars = response['placemarks']

      puts "Retrieved #{cars.length} cars"

      in_use = Log.select(:name).uniq.map(&:name) - cars.map{|c| c['name']}

      puts "Cars currently in use:"
      puts in_use.inspect

      cars.each do |car|
        current = Log.new(json: car)
        last_known = Log.last_known(car['name']).first

        if current.similar_to?(last_known)
          if last_known
            last_known.update_last_current
            last_known.save
          end
        else
          current.save
          puts "+ Saved new log entry for '#{current.name}'"
          if last_known
            diff = last_known.relevant_attributes.diff(current.relevant_attributes)
            puts "    Diff:" + diff.inspect
            if diff.has_key?('address')
              trip = Trip.create!(start: last_known, end: current)
              puts "    [#{trip.cost}] #{last_known.address} ===> #{current.address}"
            end
          end
        end
      end
    end
  end
end
