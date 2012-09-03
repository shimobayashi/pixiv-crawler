require 'rubygems'
require 'mysql'
require 'util'

class Deleter
  include Util

  def initialize()
    @mysql = getMysql
  end

  def run()
    result = @mysql.query('DELETE FROM `task` WHERE `updated_timestamp` < now() + interval -1 month')
  end
end

Deleter.new.run
