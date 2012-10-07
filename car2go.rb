require "rubygems"
require "bundler"
Bundler.require
dbconfig = YAML::load(File.open('db/config.yml'))
ActiveRecord::Base.establish_connection(dbconfig['development'])

class Log < ActiveRecord::Base
  self.table_name = 'log'
  scope :last_known, ->(name) { where(name: name).order('created_at DESC').limit(1) }

  before_create :update_last_current

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

  def update_last_current
    last_current_at = Time.now
  end
end

class Trip < ActiveRecord::Base
  belongs_to :start, class_name: "Log"
  belongs_to :end, class_name: "Log"
  validates_presence_of :start
  validates_presence_of :end

  before_save :fetch_directions

  def duration
    self.end.created_at - (self.start.last_current_at || self.start.created_at)
  end

  def cost
    sprintf("$%.2f", (duration / 60) * 0.35)
  end

  def directions
    json = super
    json = fetch_directions unless json.present?
    JSON.parse(json)
  end

  def path
    self.directions['path']
  end

  def mapquest_static_url
    "http://open.mapquestapi.com/staticmap/v4/getmap?size=512,512&type=map" +
      "&scenter=#{self.start.latitude},#{self.start.longitude}" +
      "&ecenter=#{self.end.latitude},#{self.end.longitude}" +
      "&polyline=color:0x770000ff|width:5|" +
      self.path.flatten.join(',')
  end

  def google_static_url
    "https://maps.googleapis.com/maps/api/staticmap?size=512x512&maptype=roadmap&sensor=false" +
      "&markers=color:green|label:A|#{self.start.latitude},#{self.start.longitude}" +
      "&markers=color:red|label:A|#{self.end.latitude},#{self.end.longitude}" +
      "&path=color:0x0000ff|weight:5|" +
      self.path.map{|p| p.join(',')}.join('|')
  end

  def fetch_directions(force=false)
    return directions if self[:directions].present? && !force
    guidance_response = HTTParty.get("http://open.mapquestapi.com/guidance/v1/route",
                                      query: {
                                        outFormat: 'json',
                                        from: "#{self.start.latitude},#{self.start.longitude}",
                                        to: "#{self.end.latitude},#{self.end.longitude}",
                                        generalizeAfter: 1,
                                        enableFishbone: false })
    guidance = guidance_response['guidance']

    directions_response = HTTParty.get("http://open.mapquestapi.com/directions/v1/route",
                                        query: {
                                          outFormat: 'json',
                                          from: "#{self.start.latitude},#{self.start.longitude}",
                                          to: "#{self.end.latitude},#{self.end.longitude}" })
    route = directions_response['route']

    self.directions = {
      :path => [].tap{|path| guidance['generalizedShape'].each_slice(2){|s| path << s}},
      :fuel_used => guidance['FuelUsed'],
      :duration => guidance['DefaultRouteTime'],
      :bounding_box => guidance['boundingBox'],
      :distance => route['distance'],
      :narrative => route['legs'].map{|leg| leg['maneuvers'].map{|maneuver| maneuver['narrative'] }}.flatten
    }.to_json
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
