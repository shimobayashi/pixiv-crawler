# -*- encoding:utf-8 -*-

require_relative 'pirage'
require_relative 'util'
require_relative 'task'

require 'kconv'

require 'rubygems'
require 'eventmachine'
require 'em-http'

CONCURRENCY = 512
WATCH_INTERVAL = 10
DEFAULT_TTL = 8

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
        puts "diff:#{diff}"

        #task = Task.new(:illust_id => 33292478, :tag_prefix => 'test', :bookmark_threshold => 0)
        #p task
        #fetch(task)
        #next

        if diff > 0
          tasks.skip(count).limit(diff).each do |task|
            p task
            fetch(task)
            count += 1
          end
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

    proxy = @proxies[rand(@proxies.size)]
    p proxy
    print '.'
    illust = {}
    fetchFromMemberIllust(task, ttl, proxy, illust) do
      fetchFromBookmarkDetail(task, ttl, proxy, illust) do
        if illust[:bookmarks] >= task.bookmark_threshold
          fetchFromMediumUrl(task, ttl, proxy, illust) do
            p illust[:title], illust[:tags]
            #p illust
            res = @pirage.post(illust[:artist], illust[:title], illust[:url], [task.tag_prefix, *illust[:tags]], illust[:title], illust[:medium_data])
            p 'pirage', res
            #p res.body
            if res
              task.posted = true
              task.save
            end
            puts 'done'
            @fetchCount -= 1
          end
        else
          puts 'not reached bookmark'
          @fetchCount -= 1
        end
      end
    end

    @proxies.delete!(proxy) if proxy[:score] < 0
  end

  private
  def fetchFromMemberIllust(task, ttl, proxy, illust)
    illust[:url] = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{task.illust_id}"
    req = EM::HttpRequest.new(illust[:url], {:proxy => proxy, :connect_timeout => 1}).get(:head => @head, :timeout => 8)

    req.callback do |http|
      res = http.response.toutf8
      res =~ /「(.+)」\/「(.+)」の(イラスト|漫画) \[pixiv\]/
      illust[:title], illust[:artist] = $1, $2
      res =~ /src="(http:\/\/(?!www).+?\.pixiv\.net\/img\d+\/img\/.+?\/\d+_m(\..{3})(\?\d+)?)"/
      illust[:medium_url], illust[:ext] = $1, $2
      illust[:tags] = res.scan(/<a href="\/search\.php\?s_mode=s_tag_full&.+?" class="text">(.+?)<\/a>/).map {|m| m[0]}
      illust[:tags].reject! {|m| m == '{{tag_name}}'}
      illust[:tags].uniq!

      if illust.has_value?(nil)
        p illust
        File::open('error/' + rand(10).to_s + '.html', 'w') do |f|
          f.write(res)
        end
        p 'maybe invalid response, maybe saved'
        puts 'illust has nil at title,medium_url,tags'

        illust[:url] = nil # URLはレスポンスに関係なく組み立てられるので考慮しない
        if illust.values.all? {|e| e == nil}
          puts 'BLAME!!!!!!!!!!!!!!!!!'
          proxy[:score] -= 1
          fetch(task, ttl - 1)
        else
          puts 'it seems situation changed'
          fetch(task, 0)
        end
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
        puts 'illust has nil bookmarks'
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
      if illust.has_value?(nil) || illust.has_value?('')
        puts 'illust has nil medium_data'
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
