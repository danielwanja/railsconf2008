class TwitterInstance
  
  def TwitterInstance::find(user)
    Twitter::User.find(user, twitter) # May throw a not found rest error
  end
  
  def TwitterInstance::friends(user)
    user = Twitter::User.find(user, twitter) # May throw a not found rest error
    user.friends
  end

  
  private
  
  @@twitter = nil
  def TwitterInstance::twitter
    unless @@twitter
      config_file = File.join(File.dirname(__FILE__), '..', '..', 'config', 'twitter.yml')
      @@twitter = Twitter::Client.from_config(config_file)
    end
    @@twitter
  end
  
end