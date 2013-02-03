require 'rubygems'
require 'mongo'
require 'mongoid'

class Task
  include Mongoid::Document
  include Mongoid::Timestamps

  field :illust_id, :type => Integer
  field :tag_prefix, :type => String
  field :bookmark_threshold, :type => Integer
  field :posted, :type => Boolean, :default => false

  index({illust_id: Mongo::ASCENDING}, {unique: true})
  index({created_time: Mongo::DESCENDING})

  scope :not_posted, where(:posted => false)
  scope :posted, where(:posted => true)
  scope :obsolete, where(:posted => true, :created_at => {'$lt' => DateTime.now - 3})
end
