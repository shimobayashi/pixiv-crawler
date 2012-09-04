cd /home/akimasa/hacks/pixiv-crawler/
env MONGOID_ENV=production bundle exec ruby faxiv.rb > faxiv.log 2>&1
env MONGOID_ENV=production bundle exec ruby favtags.rb > favtags.log 2>&1
env MONGOID_ENV=production bundle exec ruby favfav.rb > favfav.log 2>&1
env MONGOID_ENV=production bundle exec ruby fetcher.rb > fetcher.log 2>&1
env MONGOID_ENV=production bundle exec ruby deleter.rb > deleter.log 2>&1
