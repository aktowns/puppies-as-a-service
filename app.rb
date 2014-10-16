require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/reloader'
require 'sinatra/json'
require 'slim'

require 'flickraw'
require 'iron_cache'

FlickRaw.api_key        = ENV['FLICKR_API']
FlickRaw.shared_secret  = ENV['FLICKR_SECRET']

class FlickrStore
  def initialize
    @ironcache = IronCache::Client.new
    @cache = @ironcache.cache("flickrstore")
  end

  def get(id)
    item = @cache.get(id)
    if item.nil?
      info = flickr.photos.getInfo(photo_id: id)
      url = FlickRaw.url_o(info)
      @cache.put(id, url)
      url
    else
      item
    end
  end
end

class App < Sinatra::Base
  configure do
    set :root, File.dirname(__FILE__)
    set :flickr_store, FlickrStore.new
  end

  configure :development do
    register Sinatra::Reloader
    register Sinatra::Namespace

    helpers Sinatra::JSON
  end

  get '/' do
    slim :index
  end

  get '/why' do
    slim :why
  end

  get '/get' do
    slim :get
  end

  #
  # API
  #
  namespace '/api' do
    namespace '/v1' do
      get '/' do
        list   = flickr.photos.search(tags: 'puppy', content_type: 1).map(&:id)
        json puppies: list
      end

      get '/:id' do
        begin
          json puppy: settings.flickr_store.get(params[:id]), id: params[:id]
        rescue Exception => e
          status 500
          json error: e.message
        end
      end
    end
  end
end
