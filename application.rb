# lib/application.rb
require "sinatra"
require "httparty"

get "/" do
  if session[:access_token]
    @profiles = HTTParty.get(profiles_url, {
                  :query => {:access_token => session[:access_token]}
                }).parsed_response
  end
  haml :index
end

get "/feed" do
  if session[:access_token]
    @feed = HTTParty.get(service_data("facebook", "home"), {
                :query => {:access_token => session[:access_token], :limit => 1000}
              }).parsed_response
    @counts = @feed.inject({:all => {:name => "All", :words => {}}}) do |hash, item|
      if message = item["data"]["message"]
        from_id = item["data"]["from"]["id"]
        hash[from_id]||= {:name => item["data"]["from"]["name"], :words => {}}
        words = message.split(" ").inject({}) do |word_hash, word|
          word.downcase!
          unless forbidden_word(word)
            word_hash[word]||= 0
            word_hash[word]+= 1
          end
          word_hash
        end
        words.keys.each do |word|
          hash[from_id][:words][word] ||= 0
          hash[from_id][:words][word] += words[word]
          hash[:all][:words][word] ||= 0
          hash[:all][:words][word] += words[word]
        end
      end
      hash
    end
    @counts.except(:all).keys.inject({}) do |hash, id|
      
    end
    
    
  end
  haml :index
end

def forbidden_word(word)
  %w(a the and or it to i you in of your for it's were an is has be so let also are).include?(word)
end

def profiles_url
  "#{SINGLY_API_BASE}/profiles"
end

def service_data(service, endpoint)
  "https://api.singly.com/services/#{service}/#{endpoint}"
end

get "/auth/:service" do
  redirect auth_url(params[:service])
end

SINGLY_API_BASE = "https://api.singly.com"

def auth_params(service)
  {
    :client_id => ENV["SINGLY_ID"],
    :redirect_uri => callback_url,
    :service => service
  }.map {|key, value|
    "#{key}=#{value}"
  }.join("&")
end

def auth_url(servie)
  "#{SINGLY_API_BASE}/oauth/authorize?#{auth_params(params[:service])}"
end

def callback_url
  "http#{"s" if request.secure?}://#{request.host}:#{request.port}/auth_callback"
end

enable :sessions
                    
get "/auth_callback" do
  data = HTTParty.post(
    token_url,
    {:body => token_params(params[:code])}
  ).parsed_response
  session[:access_token] = data['access_token']
  redirect "/"
end

def token_params(code)
  {
    :client_id => ENV["SINGLY_ID"],
    :client_secret => ENV["SINGLY_SECRET"],
    :code => code
  }
end

def token_url
  "#{SINGLY_API_BASE}/oauth/access_token"
end

get "/logout" do
  session.clear
  redirect "/"
end