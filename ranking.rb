ratios = Marshal.load(open('ratios.marshal').read)
ranking = ratios.sort_by{|k,v| -v}
p ranking

ranking.select{|k,v| v <= 0.1}.each do |k, v|
  cmd = "open http://www.pixiv.net/member_illust.php?id=#{k}"
  puts cmd
  `#{cmd}`
  gets
end
