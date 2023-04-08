require "dotiw"
require "json"
require "sinatra"
require "typhoeus"

include DOTIW::Methods

set :bind, "0.0.0.0"
set :port, 4567

def fetch_and_parse(url)
  response = Typhoeus.get(url, headers: { 'Content-Type' => 'application/json' })
  JSON.parse(response.body, symbolize_names: true)[:resultSet]
end

get "/" do
  content_type :json

  house_stop = "https://developer.trimet.org/ws/v2/arrivals?appID=CAA77C07258E653CA04AADC6B&locIds=9425"

  time_start = Time.now + (40 * 60)
  time_end = Time.now + (80 * 60)
  downtown_stop = "https://developer.trimet.org/ws/v2/arrivals?appID=CAA77C07258E653CA04AADC6B&locIds=11486&begin=#{time_start.to_i}&end=#{time_end.to_i}"

  house = fetch_and_parse(house_stop)
  downtown = fetch_and_parse(downtown_stop)

  arrivals = house[:arrival].map do |arrival|
    scheduled_time = Time.at(arrival[:scheduled] / 1000)
    downtown_arrival = downtown[:arrival].find { |b| b[:tripID] == arrival[:tripID] }

    {
      busType: arrival[:vehicleID] ? "Normal" : "Bendy",
      vehicleID: arrival[:vehicleID],
      distanceAway: scheduled_time - Time.now,
      scheduled: distance_of_time_in_words(Time.now, scheduled_time, accumulate_on: :minutes, only: :minutes),
      completion: downtown_arrival ? Time.at(downtown_arrival[:scheduled] / 1000).strftime("%I:%M %p") : "unknown",
    }
  end

  {
    warning: house[:detour]&.map { |x| x[:desc] }&.join(" "),
    arrivals: arrivals.sort_by { |s| s[:distanceAway] },
    house: house,
    downtown: downtown,
  }.to_json
end
