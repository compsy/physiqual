class GoogleService < DataService
  include HTTParty

  base_uri GoogleToken.base_uri

  def initialize(token)
    @token = token
    @header = { 'Authorization' => "Bearer #{@token.token}" }
  end

  def get_sources
    @datasources = self.class.get('/dataSources', headers: @header).body
    @datasources = JSON.parse(@datasources)
    @datasources = @datasources['dataSource'].map { |x| [x['dataType']['name'], x['dataStreamId']] }
    @datasources
  end

  def get_heart_rate(from, to, _precision)
    from = convert_time_to_nanos(from)
    to = convert_time_to_nanos(to)

    res = send_get("/dataSources/derived:com.google.heart_rate.bpm:com.google.android.gms:merge_heart_rate_bpm/datasets/#{from}-#{to}")
    res = res['point']

    results = Hash.new(0)
    res = Hash[res.map do |entry|
      start = (entry['startTimeNanos'].to_i / 10e8).to_i
      endd = (entry['endTimeNanos'].to_i / 10e8).to_i
      actual_timestep = Time.at((start + endd) / 2).in_time_zone
      value = entry['value'].first['fpVal'].to_i
      results[actual_timestep] += value
      ["#{actual_timestep}", value]
    end]

    results
  end

  def get_steps(from, to)
    from = convert_time_to_nanos(from)
    to = convert_time_to_nanos(to)

    res = send_get("/dataSources/derived:com.google.step_count.delta:com.google.android.gms:estimated_steps/datasets/#{from}-#{to}")
    res = res['point']
    results_hash = Hash.new(0)

    res.each do |entry|
      start = (entry['startTimeNanos'].to_i / 10e8).to_i
      endd = (entry['endTimeNanos'].to_i / 10e8).to_i
      actual_timestep = Time.at((start + endd) / 2)

      value = entry['value'].first['intVal'].to_i
      results_hash[actual_timestep] += value
    end
    results = {}

    key = 'activities-steps'
    results[key] = []
    results_hash.each { |date, value| results[key] << { 'dateTime' => date, 'value' => value } }
    results
  end

  private

  def send_get(url)
    result = self.class.get(url, headers: @header)
    result = result.body
    JSON.parse(result)
  end

  def convert_time_to_nanos(time)
    length = 19
    time = "#{time.to_i}"
    time = "#{time}#{('0' * (length - time.length))}"
    time
  end
end
