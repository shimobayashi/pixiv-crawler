require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'util'

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
    @mysql = getMysql
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

    proxy = @proxies.slice(rand(@proxies.size), 1)[0]
    proxy = {:host => proxy[0], :port => proxy[1]}
    fetchBookmarkNewIllust(p, ttl, proxy) do |ids|
      p ids.size
      p ids
      stmt = @mysql.prepare("INSERT INTO `task` (`illust_id`,`created_timestamp`,`tag_prefix`, `bookmark_threshold`) values (?,NULL,'faxiv',8)")
      ids.each do |id|
        begin
          stmt.execute(id.to_i)
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
      http.response =~ /<section(.+)<\/section>/m
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
