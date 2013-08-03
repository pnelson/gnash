require 'active_support/time'

Chronic.time_class = ActiveSupport::TimeZone.new('Pacific Time (US & Canada)')

if memcache_servers = ENV['MEMCACHE_SERVERS']
  use Rack::Cache,
    verbose:     true,
    metastore:   "memcached://#{memcache_servers}",
    entitystore: "memcached://#{memcache_servers}"
end

get '/favicon.ico' do
  halt 404
end

get '/:grind_user_id' do
  response = Faraday.get(grind_stats_url)
  halt 502 unless response.success?
  cache_control :public, max_age: 3600 # 60 minutes
  jsonp stats: grind_stats(response.body, params[:year].to_i), updated_at: Time.now.utc
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
    stats << { start: start, finish: finish}
  end
  year == 0 ? stats : stats.select { |record| record[:start].year == year }
end
