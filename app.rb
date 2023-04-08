require "dotiw"
require "json"
require "sinatra"
require "typhoeus"

include DOTIW::Methods

BOARDING_STOP_ID = 9425
DESTINATION_STOP_ID = 11486
COMMUTE_DURATION = 40

ENV['TZ'] = 'America/Los_Angeles'

set :bind, "0.0.0.0"
set :port, 4567

def fetch_and_parse(url)
  response = Typhoeus.get(url, headers: { "Content-Type" => "application/json" })
  JSON.parse(response.body, symbolize_names: true)[:resultSet]
end

def format_time(time)
  diff = time - Time.now

  return "Now" if diff.negative?

  distance_of_time_in_words(Time.now, time, accumulate_on: :minutes, only: :minutes)
end

def build_arrivals(house, downtown)
  house[:arrival].map do |arrival|
    scheduled_time = Time.at(arrival[:scheduled] / 1000)
    estimated_time = Time.at(arrival[:estimated] / 1000)
    downtown_arrival = downtown[:arrival].find { |b| b[:tripID] == arrival[:tripID] }

    {
      busType: arrival[:vehicleID] ? "Normal" : "Bendy",
      vehicleID: arrival[:vehicleID],
      scheduled: scheduled_time.strftime("%I:%M:%S %p"),
      scheduled_pretty: format_time(scheduled_time),
      estimated: scheduled_time.strftime("%I:%M:%S %p"),
      estimated_pretty: format_time(estimated_time),
      completion: downtown_arrival ? Time.at(downtown_arrival[:scheduled] / 1000).strftime("%I:%M %p") : "unknown",
    }
  end
end

get "/" do
  content_type :json

  base_url = "https://developer.trimet.org/ws/v2/arrivals?appID=CAA77C07258E653CA04AADC6B"
  house_stop = "#{base_url}&locIds=#{BOARDING_STOP_ID}"

  time_end = Time.now + ((COMMUTE_DURATION * 2) * 60)
  downtown_stop = "#{base_url}&locIds=#{DESTINATION_STOP_ID}&begin=#{Time.now.to_i}&end=#{time_end.to_i}"

  house = fetch_and_parse(house_stop)
  downtown = fetch_and_parse(downtown_stop)

  arrivals = build_arrivals(house, downtown)

  {
    warning: house[:detour]&.map { |x| x[:desc] }&.join(" "),
    arrivals: arrivals,
  }.to_json
end
