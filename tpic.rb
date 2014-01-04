#!/usr/bin/env ruby

require 'open-uri'
require 'twitter'
require 'json'
require 'fileutils'
PIC_BASE='pics'

auth = JSON.parse IO.read('auth.json')
Twitter.configure do |config|
  config.consumer_key = auth['consumer_key']
  config.consumer_secret = auth['consumer_secret']
  config.oauth_token = auth['token']
  config.oauth_token_secret = auth['secret']
end

def collect_with_max_id(collection=[], count=200, max_id=nil, &block)
  response = nil
  if count > 200
    response = yield max_id, 200
    count -= 200
  else
    response = yield max_id, count
    count = 0
  end
  collection += response
  response.empty? ? collection.flatten : collect_with_max_id(collection, count, response.last.id - 1, &block)
end

def get_tweets(user, count=50, max_id=nil)
  collect_with_max_id([], count, max_id) do |max_id|
    options = {:count => 200, :exclude_replies => true}
    options[:max_id] = max_id unless max_id.nil?
    Twitter.user_timeline(user, options)
  end
end

def extract_image_url tweet
  tweet.media.map do |e|
    # if e.sizes[:large]
      # "#{e.media_url}:large"
    # else
      e.media_url
    # end
  end
end
def download path, url
  path = "#{PIC_BASE}/#{path}"
  return if File.exists?(path)
  puts "downloading #{url} as #{path}"
  open(path,'wb') {|f| f << open(url).read }
rescue => e
  p e
  return
end

def download_images user, images
  images.select!{|e| !(e.nil? || e['url'].empty? )}
  images.each do |img|
    next if img['url'].nil?
    img['timestamp'] = img['timestamp'].gsub(' ','0')
    if img['url'].size == 1
      download("#{user}/#{img['timestamp']}_#{img['id']}.jpg", img['url'].first)
    else
      img['url'].each.with_index do |url,index|
        download("#{user}/#{img['timestamp']}_#{img['id']}(#{index}).jpg", url)
      end
    end
  end
end
def run_cached user
  download_images user, JSON.parse(IO.read("#{PIC_BASE}/#{user}/images.json"))
end
def run user, count: nil, max_id: nil
  base = "#{PIC_BASE}/#{user}"
  unless File.exists?(base) && Dir.exists?(base)
    FileUtils.mkdir base
  end
  tweets = get_tweets user, count, max_id
  images =  tweets.map do |tweet|
    urls = extract_image_url(tweet)
    next if urls.nil? || urls.empty?
    { 'timestamp' => tweet.created_at.strftime('%Y%m%d+%H%M'),
      'url' => urls,
      'id' => tweet.id }
  end
  IO.write("#{base}/images.json", images.to_json)
  p images.first['id']
  download_images user, images
  p images.last['id']
end

require "optparse"

options = {count: 200}
user = nil
ARGV.options do |opts|
  opts.banner = "Usage:  #{File.basename($PROGRAM_NAME)} [OPTIONS] TWITTER_HANDLE"

  opts.separator ""
  opts.separator "Specific Options:"
  opts.on( "-c", "--count COUNT", Integer,
           "Count of tweets to search for images" ) do |opt|
    options[:count] = opt
  end
  opts.on( "-m", "--max-id MAXID", Integer,
           "max_id of newest tweet -> only load older tweets" ) do |opt|
    options[:max_id] = opt
  end

  opts.separator "Common Options:"

  opts.on( "-h", "--help",
           "Show this message." ) do
    puts opts
    exit
  end

  begin
    opts.parse!
    user = ARGV.first
  rescue
    puts opts
    exit
  end
end

run user, options

# case ARGV.size
# when 0
#   puts 'no user given'
#   exit 1
# when 1
#   user = ARGV.first
#   puts "getting picture in the last 200 tweets for user #{user}"
#   run user
# when 2
#   user = ARGV.first
#   count = ARGV[1].to_i
#   puts "getting picture in the last #{count} tweets for user #{user}"
#   run user, count: count
# else
#   p ARGV
# end

