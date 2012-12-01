# -*- encoding:utf-8 -*-

require_relative 'pirage'
require_relative 'util'
require_relative 'task'

require 'kconv'

require 'rubygems'
require 'eventmachine'
require 'em-http'

CONCURRENCY = 64
WATCH_INTERVAL = 10
DEFAULT_TTL = 16

class Fetcher
  include Util

  def initialize()
    @fetchCount = 0
    @pirage = Pirage.new
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
  end

  def run()
    tasks = Task.not_posted
    count = 0
    EM.run do
      EM.add_periodic_timer(WATCH_INTERVAL) do
        diff = CONCURRENCY - @fetchCount
        puts 'diff', diff

        tasks.skip(count).limit(diff).each do |task|
          p task
          fetch(task)
          count += 1
        end

        EM::stop_event_loop if Task.not_posted.count <= count and @fetchCount == 0
      end
    end
  end

  private
  def fetch(task, ttl = nil)
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
    fetchFromMemberIllust(task, ttl, proxy, illust) do
      fetchFromBookmarkDetail(task, ttl, proxy, illust) do
        if illust[:bookmarks] >= task.bookmark_threshold
          fetchFromMediumUrl(task, ttl, proxy, illust) do
            p illust[:title]
            res = @pirage.post(illust[:artist], illust[:title], illust[:url], [task.tag_prefix, *illust[:tags]], illust[:title], illust[:medium_data])
            p 'pirage', res
            if res
              task.posted = true
              task.save
            end
            @fetchCount -= 1
          end
        else
          @fetchCount -= 1
        end
      end
    end
  end

  private
  def fetchFromMemberIllust(task, ttl, proxy, illust)
    illust[:url] = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{task.illust_id}"
    req = EM::HttpRequest.new(illust[:url], {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      res = http.response.toutf8
      res =~ /「(.+)」\/「(.+)」の(イラスト|漫画) \[pixiv\]/
      illust[:title], illust[:artist] = $1, $2
      res =~ /"(http:\/\/.+\.pixiv\.net\/img\d+\/img\/.+\/\d+_m(\..{3})(\?\d+)?)"/;
      illust[:medium_url], illust[:ext] = $1, $2
      illust[:tags] = res.scan(/<a href="\/tags\.php\?tag=.+?">(.+?)<\/a>/).map {|m| m[0]}
      illust[:tags].reject! {|m| m == '{{tag_name}}'}
      illust[:tags].uniq!

      if illust.has_value?(nil)
        p illust
        puts 'illust has nil at title,medium_url,tags'
        fetch(task, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(task, ttl - 1)
    end
  end

  private
  def fetchFromBookmarkDetail(task, ttl, proxy, illust)
    req = EM::HttpRequest.new("http://www.pixiv.net/bookmark_detail.php?mode=s_tag&illust_id=#{task.illust_id}", {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      res = http.response.toutf8
      res =~ /(\d+)件のブックマーク/
      illust[:bookmarks] = $1.to_i

      if illust.has_value?(nil)
        puts 'illust has bookmarks'
        fetch(task, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(task, ttl - 1)
    end
  end

  private
  def fetchFromMediumUrl(task, ttl, proxy, illust)
    req = EM::HttpRequest.new(illust[:medium_url], {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      illust[:medium_data] = http.response.force_encoding('UTF-8')
      if illust.has_value?(nil)
        puts 'illust has medium_data'
        fetch(task, ttl - 1)
      else
        yield
      end
    end

    req.errback do
      fetch(task, ttl - 1)
    end
  end
end

Fetcher.new.run
