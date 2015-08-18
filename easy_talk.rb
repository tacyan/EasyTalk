require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

set :environment, :production

class EasyTalk
  def post(utt,context="",mode="",t="20")
    uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue?APIKEY=#{ENV["APIKEY"]}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"

    payload = {
      utt: utt,
      context: context,
      nickname: "光",
      nickname_y: "ヒカリ",
      sex: "女",
      bloodtype: "B",
      birthdateY: "1997",
      birthdateM: "5",
      birthdateD: "30",
      age: "16",
      constellations: "双子座",
      place: "東京",
      mode: mode,
      t: t
#指定無し　デフォルト
#20  関西弁
#30  赤ちゃん
    }.to_json

    req.body = payload
    res = https.request(req)
    res.body
  end
end

  post '/' do
    begin
      text = params[:text] ||= ""
      params[:user_id] ||= ""
      text.slice!(params[:trigger_word]) if params[:trigger_word]
      easy_tolk = EasyTalk.new
      response = easy_tolk.post(text,params[:user_id])
      res = JSON.parse(response)
      { text: res["utt"] }.to_json
    rescue JSON::ParserError => e
      { text: ".........................................." }.to_json
    rescue NoMethodError => e
      { text: ".........................................." }.to_json
    end
  end

  get '/test' do
    erb :test
  end

  get '/index' do
    erb :index
  end

  post '/new' do
    begin
      params[:context] ||= ""
      easy_tolk = EasyTalk.new
      response = easy_tolk.post(params[:utt],params[:context],params[:mode])
      res = JSON.parse(response).to_json
    rescue JSON::ParserError => e
      { utt: "..." }.to_json
    rescue NoMethodError => e
      { utt: "..." }.to_json
    end
  end
