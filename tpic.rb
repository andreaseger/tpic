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

def get_tweets user, count
  if count > 200
    tweets = []
    pages = (count/200)
    pages.times do |p|
      tweets << Twitter.user_timeline(user, count: 200, page: p+1)
    end
    remaining = count - pages*200
    if remaining > 0
      tweets << Twitter.user_timeline(user, count: remaining, page: pages+2)
    end
  else
    tweets = Twitter.user_timeline(user, count: count)
  end
  tweets.flatten
end

def extract_image_url tweet
  tweet.media.map do |e|
    if e.sizes[:large]
      "#{e.media_url}:large"
    else
      e.media_url
    end
  end
end
def download path, url
  return if File.exists?(path)
  puts "downloading #{url}"
  open("#{PIC_BASE}/#{path}",'wb') {|f| f << open(url).read }
end

def download_images user, images
  images.select!{|e| !(e.nil? || e['url'].empty? )}
  images.each do |img|
    next if img['url'].nil?
    img['timestamp'] = img['timestamp'].gsub(' ','0')
    if img['url'].size == 1
      download("#{user}/#{img['timestamp']}.jpg", img['url'].first)
    else
      img['url'].each.with_index do |url,index|
        download("#{user}/#{img['timestamp']}-#{index}.jpg", url)
      end
    end
  end
end
def run_cached user
  download_images user, JSON.parse(IO.read("#{PIC_BASE}/#{user}/images.json"))
end
def run user, count: 200
  unless File.exists?(user) && Dir.exists?(user)
    FileUtils.mkdir "#{PIC_BASE}/#{user}"
  end
  tweets = get_tweets user, count
  images =  tweets.map do |tweet|
    urls = extract_image_url(tweet)
    next if urls.nil? || urls.empty?
    { 'timestamp' => tweet.created_at.strftime('%y%m%d-%H%M'),
      'url' => urls }
  end
  IO.write("#{PIC_BASE}/#{user}/images.json", images.to_json)
  download_images user, images
end

case ARGV.size
when 0
  puts 'no user given'
  exit 1
when 1
  user = ARGV.first
  puts "getting picture in the last 200 tweets for user #{user}"
  run user
when 2
  user = ARGV.first
  count = ARGV[1].to_i
  puts "getting picture in the last #{count} tweets for user #{user}"
  run user, count: count
else
  p ARGV
end

