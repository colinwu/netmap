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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160302213233) do

  create_table "arpcaches", force: :cascade do |t|
    t.string   "ip",         limit: 255, default: "-", null: false
    t.string   "mac",        limit: 255, default: "-", null: false
    t.string   "router",     limit: 255, default: "-", null: false
    t.string   "if",         limit: 255, default: "-", null: false
    t.datetime "updated_at"
    t.datetime "created_at"
  end

  create_table "buildings", force: :cascade do |t|
    t.string "long_name",   limit: 255
    t.string "short_name",  limit: 255
    t.string "bldg_number", limit: 255
  end

  create_table "events", force: :cascade do |t|
    t.string   "whoEnabled",   limit: 255
    t.string   "whoDisabled",  limit: 255
    t.datetime "whenEnabled"
    t.datetime "whenDisabled"
    t.integer  "port_id",      limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.string   "comment",      limit: 255
  end

  create_table "links", force: :cascade do |t|
    t.integer  "port_a_id",  limit: 4
    t.integer  "port_b_id",  limit: 4
    t.datetime "updated_at"
    t.datetime "created_at"
  end

  create_table "nodes", force: :cascade do |t|
    t.string   "sysName",    limit: 255, default: "-",           null: false
    t.string   "ip",         limit: 255, default: "-",           null: false
    t.string   "commStr",    limit: 255, default: "**UNKNOWN**", null: false
    t.string   "platform",   limit: 255, default: "-",           null: false
    t.integer  "capability", limit: 4,   default: 0,             null: false
    t.datetime "updated_at"
    t.string   "writeStr",   limit: 255
    t.datetime "created_at"
  end

  create_table "ports", force: :cascade do |t|
    t.string   "ifName",      limit: 255, default: "-", null: false
    t.integer  "node_id",     limit: 4
    t.integer  "building_id", limit: 4
    t.integer  "vlan",        limit: 4,   default: 0,   null: false
    t.string   "label",       limit: 255, default: "-", null: false
    t.string   "comment",     limit: 255, default: "-", null: false
    t.datetime "updated_at"
    t.integer  "ifIndex",     limit: 4
    t.datetime "created_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", limit: 255
    t.text     "data",       limit: 65535
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "sys_objects", force: :cascade do |t|
    t.string "oid",  limit: 255
    t.string "name", limit: 255
  end

  create_table "users", force: :cascade do |t|
    t.string  "name",            limit: 255
    t.string  "hashed_password", limit: 255
    t.string  "salt",            limit: 255
    t.integer "level",           limit: 4
  end

end
