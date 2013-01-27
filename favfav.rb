require_relative 'util'
require_relative 'task'

require 'kconv'

require 'rubygems'
require 'eventmachine'
require 'em-http'

CONCURRENCY = 128
WATCH_INTERVAL = 10
DEFAULT_TTL = 16
PAGES = 1
FAVED_THRESHOLD = 3

class Favfav
  include Util

  def initialize()
    @fetchCount = 0
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
    @bookmarked_users = getBookmarkedUsers(@proxies, @head)
    @faved = {}
  end

  def run()
    reachFinish = false
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
        diff = CONCURRENCY - @fetchCount
        puts 'diff', diff

        diff.times do
          user_id = @bookmarked_users.slice!(0)
          p user_id
          unless user_id
            reachFinish = true
            break
          end

          PAGES.times do |p|
            fetch(user_id, p + 1)
          end
        end

        EM::stop_event_loop if reachFinish and @fetchCount == 0
      end
    end
  end

  private
  def fetch(user_id, p, ttl = nil)
    if ttl == nil
      @fetchCount += 1
      ttl = DEFAULT_TTL
    elsif ttl <= 0
      @fetchCount -= 1
      return
    end

    proxy = @proxies.slice(rand(@proxies.size), 1)[0]
    proxy = {:host => proxy[0], :port => proxy[1]}
    fetchOthersBookmark(user_id, p, ttl, proxy) do |ids|
      p user_id
      p ids.size
      p ids
      ids.each do |id|
        @faved[id] = 0 unless @faved.has_key? id
        @faved[id] += 1
        if @faved[id] == FAVED_THRESHOLD
          begin
            Task.new(:illust_id => id.to_i, :tag_prefix => 'favfav', :bookmark_threshold => 16).save
          rescue Exception => e
            p e
          end
        end
      end
      @fetchCount -= 1
    end
  end

  private
  def fetchOthersBookmark(user_id, p, ttl, proxy)
    req = EM::HttpRequest.new("http://www.pixiv.net/bookmark.php?id=#{user_id}&rest=show&p=#{p}", {:proxy => proxy}).get(:head => @head)

    req.callback do |http|
      http.response.toutf8 =~ /class=\\?"display_works(.+)class=\\?"pages/m

      ids = $1 ? $1.scan(/member_illust\.php\?mode=medium&illust_id=(\d+)/).map {|m| m[0]} : nil

      if ids and ids.size > 0
        yield ids
      else
        fetch(user_id, p, ttl - 1)
      end
    end

    req.errback do
      fetch(user_id, p, ttl -1)
    end
  end
end

Favfav.new.run

