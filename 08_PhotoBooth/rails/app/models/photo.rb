class Photo < ActiveRecord::Base
  has_attachment :storage => :file_system,
                 :use_ssl => true,
                 :s3_access => :private,
                 :min_size => 1,
                 :max_size => 5.gigabytes
  validates_as_attachment   
end
