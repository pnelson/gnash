require 'active_support/time'

Chronic.time_class = ActiveSupport::TimeZone.new('Pacific Time (US & Canada)')

configure :production do
  require 'newrelic_rpm'
end

cache = Dalli::Client.new(nil, expires_in: 3600) # 60 minutes

get '/favicon.ico' do
  halt 404
end

get '/:grind_user_id' do
  cached = cache.get(grind_stats_id)
  return jsonp cached unless cached.nil?
  response = Faraday.get(grind_stats_url)
  halt 502 unless response.success?
  rv = Hash.new
  rv[:stats] = grind_stats(response.body, params[:year].to_i)
  rv[:updated_at] = updated_at
  cache.set(grind_stats_id, rv)
  jsonp rv
end

def grind_stats_id
  params[:grind_user_id]
end

def grind_stats_url
  "http://www.grousemountain.com/grind_stats/#{grind_stats_id}?trail=1"
end

def parse_date(node)
  Chronic.parse(node.text.strip)
end

def time_in_seconds(date)
  date.hour * 60 * 60 + date.min * 60 + date.sec
end

def grind_stats(html, year)
  stats = []
  document = Nokogiri::HTML(html)
  selector = 'table.grind_log tr td'
  document.css(selector).map(&method(:parse_date)).each_slice(4) do |record|
    # correct the date as it defaults to noon
    date = record[0] - 43200
    # add the time portion of start/finish to the reported date
    start = date + time_in_seconds(record[1])
    finish = date + time_in_seconds(record[2])
    # append to the list of results
    stats << { start: start.iso8601, finish: finish.iso8601 }
  end
  year == 0 ? stats : stats.select { |record| record[:start][0..4].to_i == year }
end

def updated_at
  Time.now.utc.iso8601
end
