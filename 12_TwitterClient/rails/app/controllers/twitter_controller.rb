=begin
  Simplify code. Maybe just need to get data and send it.
  Don't cache for first version.
  Don't use "own" TwitterInstance, use explicit api Twitter::User.find(user, twitter)
  Find easy way to convert returned Twitter::User.find(user, twitter) to xml
=end
class TwitterController < ApplicationController

  def user
    render :xml => get_user(params[:id])[:xml]
  end
  
  def friends    
    render :xml => get_friends(params[:id])[:xml]
  end
  
  protected
  
  # user Hash with :user, :xml, :friends
  def get_user(username)
    unless u = @@cache[username]
      new_u = {:user => TwitterInstance.find(username)}
      new_u[:xml] = to_hash(new_u[:user]).to_xml(:root => :user, :dasherize => false)
      new_u[:friends] = nil
      u = @@cache[username] = new_u      
    end
    u
  end
  
  # friends Hash with :array, :xml 
  def get_friends(username)
    u = get_user(username)
    unless u[:friends]
      new_f = {:array => TwitterInstance.friends(username).collect {|f| to_hash(f) }}
      new_f[:xml] = new_f[:array].to_xml(:dasherize => false)
      u[:friends] = new_f
    end
    u[:friends]
  end  
  
  # Poor man's user cache
  #    name
  #    keep user instance returned from twitter
  #    friends - nil never retrieved - array retrieved
  @@cache = {}
  
  
  def to_hash(friend)
    {:id  =>  friend.id,
     :profile_image_url  =>  friend.profile_image_url,
     :description  =>  friend.description,
     :url  =>  friend.url,
     :name  =>  friend.name,
     :location  =>  friend.location,
     :screen_name  =>  friend.screen_name}
  end
  
end
