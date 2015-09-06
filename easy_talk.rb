require 'sinatra'
require 'json'
require 'net/http'
require 'uri'
require 'easy_translate'
require 'openssl'
require 'rexml/document'

#    payload = {
#      utt: utt,
#      context: context,
#      nickname: "光",
#      nickname_y: "ヒカリ",
#      sex: "女",
#      bloodtype: "B",
#      birthdateY: "1997",
#      birthdateM: "5",
#      birthdateD: "30",
#      age: "16",
#      constellations: "双子座",
#      place: "東京",
#      mode: mode,
#      t: t
#指定無し　デフォルト
#20  関西弁
#30  赤ちゃん
#    }.to_json

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

  def slack(utt,context="",t="20")
    uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue?APIKEY=#{ENV["APIKEY"]}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"

    payload = {
      utt: utt,
      context: context,
      t: t
    }.to_json

    req.body = payload
    res = https.request(req)
    res.body
  end

  def docomo(params)
    uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue?APIKEY=#{ENV["APIKEY"]}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"

    payload = {}.merge!(params).to_json

    req.body = payload
    res = https.request(req)
    res.body
  end

#  def translation
#     EasyTranslate.translate('Hello, world', :to => :japanese).tosjis
#  end

end

class Translation
  # プライマリアカウントキー see: https://datamarket.azure.com/account
  MS_TRANSLATOR_PRIMARY_KEY      = "#{ENV["MS_TRANSLATOR_PRIMARY_KEY"]}"
  # クライアントID see: https://datamarket.azure.com/developer/applications/
  MS_TRANSLATOR_CLIENT_ID        = "#{ENV["MS_TRANSLATOR_CLIENT_ID"]}"
  # クライアントID see: 顧客の秘密
  MS_TRANSLATOR_CLIENT_SECRET    = "#{ENV["MS_TRANSLATOR_CLIENT_SECRET"]}"
  MS_TRANSLATOR_ACCESSTOKEN_URL  = "#{ENV["MS_TRANSLATOR_ACCESSTOKEN_URL"]}"
  MS_TRANSLATOR_SCOPE            = "#{ENV["MS_TRANSLATOR_SCOPE"]}"
  MS_TRANSLATOR_URL              = "#{ENV["MS_TRANSLATOR_URL"]}"
  MS_TRANSLATOR_GRANT_TYPE       = "#{ENV["MS_TRANSLATOR_GRANT_TYPE"]}"

  def initialize
    @cache = {}
  end 

  # POSTしてアクセストークンを取得する
  def getAccessTokenMessage
    response = nil 

    Net::HTTP.version_1_2
    uri = URI.parse(MS_TRANSLATOR_ACCESSTOKEN_URL)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data({
      :client_id => MS_TRANSLATOR_CLIENT_ID,
      :client_secret => MS_TRANSLATOR_CLIENT_SECRET,
      :scope => MS_TRANSLATOR_SCOPE,
      :grant_type => MS_TRANSLATOR_GRANT_TYPE
      })  

    response = https.request(request)

    if response.message == "OK"
      @updateTime = Time.now
      JSON.parse(response.body)
    else
      raise "access token acquisition failure"
    end 

  end

  # キャッシュから、もしくはPOSTしてアクセストークンを取得する
  def getAccessToken(renew = false)
    renewJson = true

    if(@updateTime && @expiresIn)
      delta = Time.now - @updateTime
      if(delta <= @expiresIn.to_i - 10)
        renewJson = false
      end
    end

    if(renew)
     renewJson = true
    end

    # puts "info: renew access token" if renewJson
    @jsonResult = getAccessTokenMessage if renewJson
    @accessToken = @jsonResult["access_token"]
    @expiresIn = @jsonResult["expires_in"]

    return @accessToken
  end

  def existsTransCache(word)
    @cache.has_key?(word)
  end

  def setTransCache(word, resultWord)
    @cache[word] = resultWord
  end

  def getTransCache(word)
    @cache[word]
  end

  # wordを翻訳する
  def trans(word,from="ja",to="en")
    if existsTransCache(word)
      return getTransCache(word)
    end
    access_token = getAccessToken

    Net::HTTP.version_1_2
    uri = URI.parse(MS_TRANSLATOR_URL)
    http = Net::HTTP.new(uri.host, uri.port)
        params = {
      :text => word,
      :from => from,
      :to => to
      }
    query_string = params.map{ |k,v|
      URI.encode(k.to_s) + "=" + URI.encode(v.to_s)
    }.join("&")

    request = Net::HTTP::Get.new(uri.path + "?" + query_string)
    request['Authorization'] = "Bearer #{access_token}"

    response = http.request(request)

    result = nil
    # response.body
    # => <string xmlns="http://schemas.microsoft.com/2003/10/Serialization/">サンプル</string>
    if response.message == "OK"
      document = REXML::Document.new(response.body)
      result = document.root.text
      setTransCache(word, result)
    end

    result
  end
#
end

  post '/slack' do
    begin
      body = request.body.read
      params = JSON.parse(body)
      text = params["text"] ||= ""
      params["user_id"] ||= ""
      text.slice!(params[:trigger_word]) if params["trigger_word"]
      easy_tolk = EasyTalk.new
      response = easy_tolk.slack(text,params["user_id"])
      res = JSON.parse(response)
      res["utt"].to_s
    rescue JSON::ParserError => e
      { text: ".........................................." }.to_json
    rescue NoMethodError => e
      { text: ".........................................." }.to_json
    end
  end

  post '/translation' do
    body = request.body.read
    params = JSON.parse(body)
    text = params["text"]
    from = params["from"]
    to = params["to"]
    honyaku = Translation.new
    honyaku.trans("#{text}","#{from}","#{to}").to_s
  end

  post '/docomo' do
    body = request.body.read
    params = JSON.parse(body)
    easy_tolk = EasyTalk.new
    response = easy_tolk.docomo(params)
    res = JSON.parse(response)
    res.to_json
  end

  get '/test' do
    erb :test
  end

  get '/' do
    erb :index
  end

  post '/new' do
    begin
      params[:context] ||= ""
      easy_tolk = EasyTalk.new
      response = easy_tolk.post(params[:utt],params[:context],params[:mode],params[:t])
      res = JSON.parse(response).to_json
    rescue JSON::ParserError => e
      { utt: ".........................................." }.to_json
    rescue NoMethodError => e
      { utt: ".........................................." }.to_json
    end
  end
