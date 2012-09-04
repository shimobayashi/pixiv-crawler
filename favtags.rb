require_relative 'util'
require_relative 'task'

require 'rubygems'
require 'eventmachine'
require 'em-http'

WATCH_INTERVAL = 10
DEFAULT_TTL = 16
PAGES = 3

class Favtags
  include Util

  def initialize()
    @fetchCount = 0
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
  end

  def run()
    tags = getFavoriteTags()
    EM.run do
      tags.each do |tag|
        PAGES.times do |p|
          fetch(tag['word'], tag['bookmark_threshold'], p + 1)
        end
      end
      EM.add_periodic_timer(WATCH_INTERVAL) do
        EM.stop_event_loop if @fetchCount == 0
      end
    end
  end

  private
  def fetch(word, bookmark_threshold, p, ttl = nil)
    if ttl == nil
      @fetchCount += 1
      ttl = DEFAULT_TTL
    elsif ttl <= 0
      @fetchCount -= 1
      return
    end

    proxy = @proxies.slice(rand(@proxies.size), 1)[0]
    proxy = {:host => proxy[0], :port => proxy[1]}
    fetchSearch(word, bookmark_threshold, p, ttl, proxy) do |ids|
      p ids.size
      p ids
      ids.each do |id|
        begin
          Task.new(:illust_id => id.to_i, :tag_prefix => 'favtags', :bookmark_threshold => bookmark_threshold.to_i).save
        rescue Exception => e
          p e
        end
      end
      @fetchCount -= 1
    end
  end

  private
  def fetchSearch(word, bookmark_threshold, p, ttl, proxy)
    s_mode = 's_tag'
    req = EM::HttpRequest.new("http://www.pixiv.net/search.php?word=#{URI.encode(word)}&s_mode=#{s_mode}&p=#{p}", {:proxy => proxy}).get(:head => @head)

    req.callback do |http|
      http.response =~ /<section(.+)<\/section>/m
      ids = $1 ? $1.scan(/member_illust\.php\?mode=medium&amp;illust_id=(\d+)/).map {|m| m[0]} : nil

      if ids and ids.size > 0
        yield ids
      else
        fetch(word, bookmark_threshold, p, ttl - 1)
      end
    end

    req.errback do
      fetch(word, bookmark_threshold, p, ttl -1)
    end
  end
end

Favtags.new.run

