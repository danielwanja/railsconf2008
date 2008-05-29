class Asset < ActiveRecord::Base
  belongs_to :account
  
  has_attachment :storage => :s3, #:file_system
                 :use_ssl => true,
                 :s3_access => :private,
                 :min_size => 1,
                 :max_size => 5.gigabytes
  validates_as_attachment
end
