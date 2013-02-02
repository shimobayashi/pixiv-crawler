require_relative 'util'
require_relative 'task'

class Rankiv
  include Util

  def initialize
    @proxies = getProxies
    cookie = getCookie(@proxies)
    p cookie
    @head = getRequestHeader(cookie)
    @targets = ['/ranking.php?mode=daily', '/ranking.php?mode=daily_r18', '/ranking.php?mode=r18g']
  end

  def run
    @targets.each do |target|
      ids = fetch(target)
      ids[0..10].each do |id|
        Task.new(:illust_id => id, :tag_prefix => 'rankiv', :bookmark_threshold => 0).save
      end
    end
  end

  def fetch(url)
    while true
      begin
        proxy = @proxies[rand(@proxies.size)]
        proxy = [proxy[:host], proxy[:port]]
        p proxy
        http = Net::HTTP::Proxy(*proxy).new('www.pixiv.net', 80)
        http.open_timeout = 8
        http.read_timeout = 8
        http.start do |http|
          req = Net::HTTP::Get.new(url)
          @head.each {|k, v| req[k] = v}
          res = http.request(req)
          ids = res.body.scan(/member_illust\.php\?mode=medium&amp;illust_id=(\d+)/).map {|m| m[0]}
          ids.uniq!
          p ids
          return ids if ids.size > 0
        end
      rescue Exception => e
        puts e.message
        next
      end
    end
  end
end

Rankiv.new.run
