require_relative 'util'
require_relative 'task'

require 'kconv'

require 'rubygems'
require 'eventmachine'
require 'em-http'

CONCURRENCY = 128
WATCH_INTERVAL = 10
DEFAULT_TTL = 32
PAGES = 278

class Getbookmarks
  include Util

  def initialize()
    @fetchCount = 0
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
@pages = (1..PAGES).to_a
@bookmarked = []
  end

  def run()
    reachFinish = false
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
        diff = CONCURRENCY - @fetchCount
        puts 'diff', diff

        diff.times do
          page = @pages.slice!(0)
          p page
          unless page
            reachFinish = true
            break
          end

fetch(page)
        end

        EM::stop_event_loop if reachFinish and @fetchCount == 0
      end
    end

p @bookmarked
p @bookmarked.size
open('bookmarks.marshal', 'w').write(Marshal.dump(@bookmarked))
  end

  private
  def fetch(page, ttl = nil)
    if ttl == nil
      @fetchCount += 1
      ttl = DEFAULT_TTL
    elsif ttl <= 0
p 'fuck'
      @fetchCount -= 1
      return
    end

    proxy = @proxies[rand(@proxies.size)]
fetchBookmark(page, ttl, proxy) do |ids|
#p page
#p ids.size
#p ids
print '.'
@bookmarked += ids
@fetchCount -= 1
end
  end

  private
  def fetchBookmark(page, ttl, proxy)
    req = EM::HttpRequest.new("http://www.pixiv.net/bookmark.php?rest=show&p=#{page}", {:proxy => proxy}).get(:head => @head)

    req.callback do |http|
      http.response.toutf8 =~ /<ul class="image-items(.+?)<\/ul>/m

      ids = http.response.toutf8.scan(/member_illust\.php\?mode=medium&amp;illust_id=(\d+)/).map {|m| m[0]}

      if ids and ids.size > 0
        yield ids
      else
        fetch(page, ttl - 1)
      end
    end

    req.errback do
      fetch(page, ttl -1)
    end
  end
end

Getbookmarks.new.run

