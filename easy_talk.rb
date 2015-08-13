require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

set :environment, :production

class EasyTalk
  def post(utt)
    uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue?APIKEY=#{ENV["APIKEY"]}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"

    payload = {
      utt: "#{utt}",
      context: "",
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
      mode: "dialog"
    }.to_json

    req.body = payload
    res = https.request(req)
    res.body
  end
end

  get '/' do
    easy_tolk = EasyTalk.new
    puts easy_tolk.post("元気ですか！？")
  end
