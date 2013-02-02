require_relative 'util'
require_relative 'task'

require 'kconv'

require 'rubygems'
require 'eventmachine'
require 'em-http'

WATCH_INTERVAL = 10
DEFAULT_TTL = 16
PAGES = 3

class Faxiv
  include Util

  def initialize()
    @fetchCount = 0
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
  end

  def run()
    EM.run do
      PAGES.times do |p|
        fetch(p + 1)
      end
      EM.add_periodic_timer(WATCH_INTERVAL) do
        EM.stop_event_loop if @fetchCount == 0
      end
    end
  end

  private
  def fetch(p, ttl = nil)
    if ttl == nil
      @fetchCount += 1
      ttl = DEFAULT_TTL
    elsif ttl <= 0
      @fetchCount -= 1
      return
    end

    proxy = @proxies[rand(@proxies.size)]
    fetchBookmarkNewIllust(p, ttl, proxy) do |ids|
      p ids.size
      p ids
      ids.each do |id|
        begin
          Task.new(:illust_id => id.to_i, :tag_prefix => 'faxiv', :bookmark_threshold => 16).save
        rescue Exception => e
          p e
        end
      end
      @fetchCount -= 1
    end
  end

  private
  def fetchBookmarkNewIllust(p, ttl, proxy)
    req = EM::HttpRequest.new("http://www.pixiv.net/bookmark_new_illust.php?mode=new&p=#{p}", {:proxy => proxy}).get(:head => @head)

    req.callback do |http|
      http.response.toutf8 =~ /<section(.+)<\/section>/m
      ids = $1 ? $1.scan(/member_illust\.php\?mode=medium&amp;illust_id=(\d+)/).map {|m| m[0]} : nil

      if ids and ids.size > 0
        yield ids
      else
        fetch(p, ttl - 1)
      end
    end

    req.errback do
      fetch(p, ttl -1)
    end
  end
end

Faxiv.new.run
