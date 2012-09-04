require_relative 'util'
require_relative 'task'

class Deleter
  include Util

  def run()
    Task.obsolete.destroy
  end
end

Deleter.new.run
