module GoMap
  class Log < ActiveRecord::Base
    self.table_name = 'log'
    scope :last_known, ->(name) { where(name: name).order('created_at DESC').limit(1) }
    scope :current_at, ->(time) { where('created_at <= :time AND last_current_at >= :time', time: time) }

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
      attributes.reject{|k,v| %w(id created_at updated_at last_current_at).include?(k) }
    end

    def update_last_current
      self.last_current_at = Time.now
    end
  end
end
