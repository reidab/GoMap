module GoMap
  class Trip < ActiveRecord::Base
    belongs_to :start, class_name: "Log"
    belongs_to :end, class_name: "Log"
    validates_presence_of :start
    validates_presence_of :end

    before_save :fetch_directions

    def car_name
      self.start.name
    end

    def directions
      json = super
      json = fetch_directions unless json.present?
      JSON.parse(json)
    end

    %w(path distance narrative).each do |key|
      define_method(key) do
        self.directions[key]
      end
    end

    def estimated_fuel_used
      self.directions['fuel_used']
    end

    def estimated_duration
      self.directions['duration']
    end

    def start_time
      self.start.last_current_at
    end

    def end_time
      self.end.created_at
    end

    def duration
      end_time - start_time
    end

    def cost
      sprintf("$%.2f", (duration / 60) * 0.35)
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
end
