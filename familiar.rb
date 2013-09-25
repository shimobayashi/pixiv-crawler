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

class Familiar
  include Util

  def initialize()
    @fetchCount = 0
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
    @bookmarked_users = getBookmarkedUsers(@proxies, @head)
@bookmarks = Marshal.load(open('bookmarks.marshal').read)
@ratios = {}
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

p @ratios
open('ratios.marshal', 'w').write(Marshal.dump(@ratios))
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

    proxy = @proxies[rand(@proxies.size)]
fetchPosted(user_id, p, ttl, proxy) do |ids|
p user_id
p ids.size
product = ids & @bookmarks
p product.size
@ratios[user_id] = product.size / ids.size.to_f
@fetchCount -= 1
end
  end

  private
  def fetchPosted(user_id, p, ttl, proxy)
    req = EM::HttpRequest.new("http://www.pixiv.net/member_illust.php?id=#{user_id}&p=#{p}", {:proxy => proxy}).get(:head => @head)

    req.callback do |http|
      http.response.toutf8 =~ /<ul class="image-items(.+?)<\/ul>/m

      ids = http.response.toutf8.scan(/member_illust\.php\?mode=medium&amp;illust_id=(\d+)/).map {|m| m[0]}

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

Familiar.new.run
