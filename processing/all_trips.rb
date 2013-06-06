# All Trips

require "../environment"

class AllTrips < Processing::App
  load_library 'modestmaps'

  import 'com.modestmaps'
  import 'com.modestmaps.core'
  import 'com.modestmaps.geo'
  import 'com.modestmaps.providers'

  def setup
    background 25
    stroke 255
    fill 0, 137, 220, 255
    ellipse_mode CENTER
    ellipse 10,10,10,10

    center = Location.new(45.5236, -122.6600)
    background_map = StaticMap.new(self, 
                      TemplatedMapProvider.new("http://tile.stamen.com/terrain-background/{Z}/{X}/{Y}.png"), 
                      Point2f.new(width, height), 
                      center, 13)
    lines = StaticMap.new(self, 
                      TemplatedMapProvider.new("http://tile.stamen.com/terrain-lines/{Z}/{X}/{Y}.png"), 
                      Point2f.new(width, height), 
                      center, 13)
  
    @background_image = background_map.draw(true)
    @lines_image = lines.draw(true)
    # @lines_image = @background_image

    image(@background_image,0,0)
    image(@lines_image,0,0)
    
    center_point = background_map.locationPoint2f(center)

    @date = Date.today - 5

    @map = background_map
    @start_time = Log.first.created_at
    @start_time = @date.beginning_of_day
    # @end_time = @date.end_of_day
    @end_time = Time.now
    @time = @start_time
  end

  def draw_path(path)
    path.each_with_index do |point, i|
      next if i == 0
      lstart = @map.locationPoint2f(Location.new(*point))
      lend = @map.locationPoint2f(Location.new(*path[i-1]))

      line(lstart.x, lstart.y, lend.x, lend.y)
    end
  end
  
  def draw
    tint 255, 64
    image(@background_image,0,0)
    image(@lines_image,0,0)

    fill 0, 137, 220, 50
    stroke 255
    Log.current_at(@time).each do |l|
      loc = Location.new(l.latitude, l.longitude)
      point = @map.locationPoint2f(loc)
      ellipse point.x, point.y, 10, 10
    end

    Trip.active_at(@time).each do |trip|
      stroke 20, 109, 171, 230
      stroke_weight 3
      # draw_path(trip.completed_path_at(@time))

      fill 0, 137, 220, 255
      stroke 255
      stroke_weight 1
      loc = Location.new(*trip.location_at(@time))
      point = @map.locationPoint2f(loc)
      ellipse point.x, point.y, 10, 10
    end
    
    text @time.to_s, 10, 10

    @time += 30.seconds
    # save_frame
    exit if @time > @end_time
    @time = @start_time if @time > @end_time
  end
  
end

# AllTrips.new :title => "All Trips", :width => 1280, :height => 720
# AllTrips.new :title => "All Trips", :width => 800, :height => 800
AllTrips.new :title => "All Trips", :width => 1920, :height => 1080

