require 'rubygems'
require 'mongoid'

class Task
  include Mongoid::Document
  include Mongoid::Timestamps

  field :illust_id, :type => Integer
  field :tag_prefix, :type => String
  field :bookmark_threshold, :type => Integer
end
