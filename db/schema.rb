# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20121007065218) do

  create_table "log", :force => true do |t|
    t.string   "address"
    t.string   "engine_type"
    t.string   "exterior_condition"
    t.string   "interior_condition"
    t.string   "name"
    t.string   "vin"
    t.integer  "fuel"
    t.boolean  "charging"
    t.decimal  "latitude",           :precision => 10, :scale => 6
    t.decimal  "longitude",          :precision => 10, :scale => 6
    t.decimal  "altitude",           :precision => 10, :scale => 6
    t.datetime "created_at",                                        :null => false
    t.datetime "updated_at",                                        :null => false
  end

  create_table "trips", :force => true do |t|
    t.integer "start_id"
    t.integer "end_id"
    t.text    "directions"
  end

end
