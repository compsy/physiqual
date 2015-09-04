module DataServices
  class DataService
    DATE_FORMAT = '%Y-%m-%d'
    def service_name
      'general dataservice'
    end

    def steps(_from, _to)
      fail 'Subclass does not implement steps method.'
    end

    def heart_rate(_from, _to)
      fail 'Subclass does not implement heart_rate method.'
    end

    def sleep(_from, _to)
      fail 'Subclass does not implement sleep method.'
    end

    def calories(_from, _to)
      fail 'Subclass does not implement calories method.'
    end

    def activities(_from, _to)
      fail 'Subclass does not implement activities method.'
    end

    def key
      'activities'
    end

    def date_time_field
      'dateTime'
    end

    def values_field
      'values'
    end

    def output_entry(date, values)
      {
        date_time_field => date,
        values_field => [values].flatten
      }
    end
  end
end