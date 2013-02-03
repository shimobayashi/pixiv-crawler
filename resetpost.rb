require_relative 'util'
require_relative 'task'

# fetcher.rbが腐って投稿できてないのに投稿できたことにしてしまっていたときのためにスクリプト

class ResetPost
  include Util

  def run()
    Task.posted.each do |task|
      task.posted = false
    end
  end
end

ResetPost.new.run
