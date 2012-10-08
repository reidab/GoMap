require "rubygems"
require "bundler"
Bundler.require

ROOT_PATH = File.dirname(__FILE__)

dbconfig = YAML::load(File.open(File.join(ROOT_PATH, 'db/config.yml')))
ActiveRecord::Base.establish_connection(dbconfig['development'])

Dir.glob(File.join(ROOT_PATH, 'lib','go_map','*.rb')).each {|rb|
  require rb
}

include GoMap
