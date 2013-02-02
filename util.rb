#-*- encoding: utf-8 -*-

require 'net/http'
require 'yaml'

require 'rubygems'
require 'mechanize'
require 'mongo'
require 'mongoid'

Mongoid.load!('mongoid.yaml')

module Util
  def getProxies()
    proxies = []
    agent = Mechanize.new
    #page = agent.get('http://www.cybersyndrome.net/pla5.html')
    #page.search('//li/a[@class="A"]/..').each do |classA|
    #  proxies << classA.inner_text.split(':')
    #end
    page = agent.get('http://www.cybersyndrome.net/plr5.html')
    page.search('//li/a/..').each do |li|
      proxy = li.inner_text.split(':')
      proxies << {:host => proxy[0], :port => proxy[1], :score => 8}
    end
    proxies
  end

  def getCookie(proxies)
    account = YAML.load_file('account.yaml')
    cookie = {}
    while cookie == {}
      begin
        proxy = proxies[rand(proxies.size)]
        proxy = [proxy[:host], proxy[:port]]
        p proxy
        http = Net::HTTP::Proxy(*proxy).new('www.pixiv.net', 80)
        http.open_timeout = 8
        http.read_timeout = 8
        http.start do |http|
          req = Net::HTTP::Post.new('/login.php')
          req.set_form_data({'pixiv_id' => account['id'], 'pass' => account['pass'], 'mode' => 'login'})
          res = http.request(req)
          res.get_fields('Set-Cookie').each do |str|
            k, v = str[0 ... str.index(';')].split('=')
            cookie[k] = v
          end
        end
      rescue Exception => e
        puts e.message
        next
      end
    end
    cookie
  end

  def getRequestHeader(cookie = {})
    head = {}
    head['user-agent'] = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)'
    head['accept-language'] = 'ja'
    head['referer'] = 'http://www.pixiv.net/mypage.php'
    head['cookie'] = cookie.map{|k, v| "#{k}=#{v}"}.join(';')
    head
  end

  def getFavoriteTags()
    YAML.load_file('favtags.yaml')
  end

  def getBookmarkedUsers(proxies, head)
    reachedFinish = false
    bookmarked_users = []
    p = 1
    while !reachedFinish
      begin
        proxy = proxies[rand(proxies.size)]
        proxy = [proxy[:host], proxy[:port]]
        p proxy

        while !reachedFinish
          http = Net::HTTP::Proxy(*proxy).new('www.pixiv.net', 80)
          http.open_timeout = 2
          http.read_timeout = 2
          http.start do |http|
            p p
            req = Net::HTTP::Get.new("/bookmark.php?type=user&rest=show&p=#{p}")
            head.each {|k, v| req[k] = v}
            res = http.request(req)
            tmp = res.body.scan(/<input name="id\[\]" value="(\d+)"/).map {|m| m[0]}
            p tmp
            reachedFinish = true if tmp.size <= 0
            bookmarked_users += tmp
            p += 1
          end
        end
      rescue Exception => e
        puts e.message
        next
      end
    end
    bookmarked_users.uniq!
    puts 'bookmarked_users.size', bookmarked_users.size
    bookmarked_users
  end
end
