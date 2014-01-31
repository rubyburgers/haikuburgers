require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'faraday'
require 'json'
require 'jsonpath'
require 'dotenv' if ENV['RACK_ENV'] != 'production'
require 'pg'
require 'sequel'
require "dalli"
require "rack-cache"
class App < Sinatra::Base
  Dotenv.load if ENV['RACK_ENV'] != 'production'

  DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost:15432/haikuburgers')
  DB.create_table? :haikus do
    primary_key :id
    String :text
  end

  get '/' do
    cache_control :public, max_age: 3600 * 24 * 365  # 30 mins.
    haikus = DB[:haikus].map(:text)
    haikus.to_json
    erb :index, locals: { haikus: haikus }
  end

  post '/refresh' do
    content_type :json
    conn = Faraday.new(:url => 'http://api.meetup.com')
    profiles = JSON.parse(conn.get('/2/profiles' , group_id: 5356052,  key: ENV['MEETUP_API_KEY'], fields: 'join_info').body)
    path = JsonPath.new('$..answers')
    path.on(profiles)
    DB[:haikus].delete
    answers = path.on(profiles).flatten.select{ |answer| answer["question_id"] == 2859752 }.each do |answer|
      DB[:haikus].insert({text: answer['answer']})
    end
    { answers: answers }.to_json
  end
end
