module GoMap
  class Trip < ActiveRecord::Base
    belongs_to :start, class_name: "Log"
    belongs_to :end, class_name: "Log"
    validates_presence_of :start
    validates_presence_of :end

    before_save :fetch_directions
    before_save :cache_times_and_car_name

    scope :active_at, ->(time) { where('start_time <= :time AND end_time >= :time', time: time) }

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

    def duration
      end_time - start_time
    end

    def cost
      sprintf("$%.2f", (duration / 60) * 0.35)
    end

    # GEOS Calculations

    def geos_wkt_reader
      @geos_reader ||= Geos::WktReader.new
    end

    def geos_line_string
      @geos_line_string ||= geos_wkt_reader.read("LINESTRING(#{path.map{|p| p.reverse.join(' ')}.join(', ')})")
    end

    def time_percent(time)
      time_percent = (time - start_time) / duration
    end

    def distance_travelled_at(time)
      time_percent(time) * geos_line_string.length
    end

    def geos_point_at(time)
      geos_line_string.interpolate(distance_travelled_at(time))
    end

    def location_at(time)
      geos_point = geos_point_at(time)
      [geos_point.y, geos_point.x]
    end

    def completed_path_at(time)
      return path if geos_point_at(time) == geos_line_string.end_point
      dist = distance_travelled_at(time)

      # there's a better way to do this in the GEOS C code, but the FFI bindings don't expose it

      0.upto(path.size - 1) do |i|
        p = path[0..i]
        p *= 2 if p.size == 1 # ensure a valid line string
        ls = geos_wkt_reader.read("LINESTRING(#{p.map{|p| p.reverse.join(' ')}.join(', ')})")
        if ls.interpolate(dist) == ls.end_point
          # we've covered this entire path and can move on
        else
          return p[0..-2] << location_at(time)
        end
      end
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

    def cache_times_and_car_name(force=false)
      self.start_time = self.start.last_current_at if force || self.start_time.nil?
      self.end_time   = self.end.created_at if force || self.end_time.nil?
      self.car_name   = self.start.name if force || self.car_name.nil?
      self.estimated_start_time = self.end_time - self.estimated_duration if force || self.estimated_start_time.nil?
    end
  end
end
