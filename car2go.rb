require "rubygems"
require "bundler"
Bundler.require
dbconfig = YAML::load(File.open('db/config.yml'))
ActiveRecord::Base.establish_connection(dbconfig['development'])

class Log < ActiveRecord::Base
  self.table_name = 'log'
  scope :last_known, ->(name) { where(name: name).order('created_at DESC').limit(1) }

  def initialize(attrs = {})
    if json = attrs.delete(:json)
      super({
        address: json['address'],
        engine_type: json['engineType'],
        exterior_condition: json['exterior'],
        interior_condition: json['interior'],
        name: json['name'],
        vin: json['vin'],
        fuel: json['fuel'],
        charging: json['charging'],
        longitude: json['coordinates'][0],
        latitude: json['coordinates'][1],
        altitude: json['coordinates'][2]
      })
    else
      super(attrs)
    end
  end

  def similar_to?(other)
    return false unless other
    self.relevant_attributes == other.relevant_attributes
  end

  def relevant_attributes
    attributes.reject{|k,v| %w(id created_at updated_at).include?(k) }
  end
end

class Trip < ActiveRecord::Base
  belongs_to :start, class_name: "Log"
  belongs_to :end, class_name: "Log"
  validates_presence_of :start
  validates_presence_of :end

  before_save :fetch_directions

  def duration
    self.end.created_at - self.start.created_at
  end

  def cost
    sprintf("$%.2f", (duration / 60) * 0.35)
  end

  def directions
    json = super
    json = fetch_directions unless json.present?
    JSON.parse(json)
  end

  def narrative
    self.directions['route']['legs'].map{|leg|
      leg['maneuvers'].map{|maneuver| 
        maneuver['narrative']
      }
    }.flatten
  end

  def path
    path = []

    self.directions['route']['legs'].each{|leg|
      leg['maneuvers'].each{|maneuver| 
        path << [maneuver['startPoint']['lng'], maneuver['startPoint']['lat']]
      }
    }

    path
  end

  def fetch_directions(force=false)
    return directions if self[:directions].present? && !force
    response = HTTParty.get("http://open.mapquestapi.com/directions/v1/route",
                            query: {
                              outFormat: 'json',
                              from: "#{self.start.latitude},#{self.start.longitude}",
                              to: "#{self.end.latitude},#{self.end.longitude}" })

    self.directions = response.body
  end

  def update_directions
    fetch_directions(true)
  end
end

LOCATION = 'portland'
CONSUMER_KEY = 'GoMap'

puts ""
puts "=" * 80
puts "Starting run at #{Time.now}"

response = HTTParty.get("http://www.car2go.com/api/v2.1/vehicles", 
                        query: { loc: LOCATION,
                                 oauth_consumer_key: CONSUMER_KEY,
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
    # puts "- No change for '#{current.name}'"
  else
    current.save
    puts "+ Saved new log entry for '#{current.name}'"
    if last_known
      puts "    Diff:" + last_known.relevant_attributes.diff(current.relevant_attributes).inspect
      trip = Trip.create!(start: last_known, end: current)
      puts "    [#{trip.cost}] #{last_known.address} ===> #{current.address}"
      # puts trip.narrative.map{|n| "     - " + n}
    end
  end
end
