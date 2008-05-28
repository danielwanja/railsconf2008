class TwitterController < ApplicationController

  @@twitter = Twitter::Client.from_config(
                File.join(File.dirname(__FILE__), '..', '..', 'config', 'twitter.yml'))

  def user
    render :xml => account.user 
  end
  
  def friends    
    acc = account
    unless acc.friends
      u = Twitter::User.find(params[:id], @@twitter)
      acc.update_attribute(
                  'friends', 
                  u.friends.collect {|f| to_hash(f) }.to_xml(:dasherize => false))
    end
    render :xml => acc.friends
  end
  
  
=begin
  Non cached version
  def user
    u =  Twitter::User.find(params[:id], @@twitter)
    render :xml => to_hash(u).to_xml(:root => :user, :dasherize => false)
  end

  def friends    
    u = Twitter::User.find(params[:id], @@twitter)
    f = u.friends
    a = f.collect {|f| to_hash(f) }
    render :xml => a.to_xml(:dasherize => false)
  end
=end  
    
  protected
  
  def account
    acc = Account.find_or_initialize_by_name(params[:id])
    if acc.new_record? #Not in db, let's retrieve and store
      u =  Twitter::User.find(params[:id], @@twitter)
      acc.user = to_hash(u).to_xml(:root => :user, :dasherize => false)
      acc.save
    end  
    acc  
  end
  
  def to_xml(user)
    to_hash(user)
  end  
  
  def to_hash(user)
    {:id  =>  user.id,
     :profile_image_url  =>  user.profile_image_url,
     :description  =>  user.description,
     :url  =>  user.url,
     :name  =>  user.name,
     :location  =>  user.location,
     :screen_name  =>  user.screen_name}
  end
  
end
