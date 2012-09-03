require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'pirage'
require 'util'

CONCURRENCY = 64
WATCH_INTERVAL = 10
DEFAULT_TTL = 16

class Fetcher
  include Util

  def initialize()
    @fetchCount = 0
    @mysql = getMysql
    @pirage = Pirage.new
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
  end

  def run()
    result = @mysql.query('SELECT * FROM `task` WHERE `posted`=0 ORDER BY `created_timestamp` DESC')
    #result = @mysql.query('SELECT * FROM `task` ORDER BY `created_timestamp` DESC LIMIT 8')
    reachFinish = false
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
        diff = CONCURRENCY - @fetchCount
        puts 'diff', diff

        diff.times do
          row = result.fetch_hash
          unless row
            reachFinish = true
            break
          end

          p row
          fetch(row)
        end

        EM::stop_event_loop if reachFinish and @fetchCount == 0
      end
    end
  end

  private
  def fetch(row, ttl = nil)
    if ttl == nil
      @fetchCount += 1
      ttl = DEFAULT_TTL
    elsif ttl <= 0
      puts 'ttl reaches 0'
      @fetchCount -= 1
      return
    end

    proxy = @proxies.slice(rand(@proxies.size), 1)[0]
    proxy = {:host => proxy[0], :port => proxy[1]}
    #p proxy
    print '.'
    illust = {}
    fetchFromMemberIllust(row, ttl, proxy, illust) do
      fetchFromBookmarkDetail(row, ttl, proxy, illust) do
        if illust[:bookmarks] >= row['bookmark_threshold'].to_i
          fetchFromMediumUrl(row, ttl, proxy, illust) do
            p illust[:title]
            res = @pirage.post(illust[:artist], illust[:title], illust[:url], [row['tag_prefix'], *illust[:tags]], illust[:title], illust[:medium_data])
            p 'pirage', res
            stmt = @mysql.prepare('UPDATE `task` SET `posted`=1 WHERE `id`=?')
            stmt.execute(row['id'])
            @fetchCount -= 1
          end
        else
          @fetchCount -= 1
        end
      end
    end
  end

  private
  def fetchFromMemberIllust(row, ttl, proxy, illust)
    illust[:url] = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{row['illust_id']}"
    req = EM::HttpRequest.new(illust[:url], {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      http.response =~ /「(.+)」\/「(.+)」の(イラスト|漫画) \[pixiv\]/
      illust[:title], illust[:artist] = $1, $2
      http.response =~ /"(http:\/\/.+\.pixiv\.net\/img\d+\/img\/.+\/\d+_m(\..{3})(\?\d+)?)"/;
      illust[:medium_url], illust[:ext] = $1, $2
      illust[:tags] = http.response.scan(/<a href="tags\.php\?tag=.+?">(.+?)<\/a>/).map {|m| m[0]}

      if illust.has_value?(nil)
        p illust
        puts 'illust has nil at title,medium_url,tags'
        fetch(row, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(row, ttl - 1)
    end
  end

  private
  def fetchFromBookmarkDetail(row, ttl, proxy, illust)
    req = EM::HttpRequest.new("http://www.pixiv.net/bookmark_detail.php?mode=s_tag&illust_id=#{row['illust_id']}", {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      http.response =~ /(\d+)件のブックマーク/
      illust[:bookmarks] = $1.to_i

      if illust.has_value?(nil)
        puts 'illust has bookmarks'
        fetch(row, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(row, ttl - 1)
    end
  end

  private
  def fetchFromMediumUrl(row, ttl, proxy, illust)
    req = EM::HttpRequest.new(illust[:medium_url], {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      illust[:medium_data] = http.response
      if illust.has_value?(nil)
        puts 'illust has medium_data'
        fetch(row, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(row, ttl - 1)
    end
  end
end

Fetcher.new.run
