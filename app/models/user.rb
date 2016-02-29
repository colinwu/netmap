class User < ActiveRecord::Base
  validates_presence_of   :name
  validates_presence_of   :password, :on => :create
  validates_confirmation_of   :password
  validates_uniqueness_of :name
  validates_length_of     :password,
                          :minimum => 5,
                          :message => "Must be at least 5 characters long",
                          :on => :create
  attr_accessor           :password

#   before_save :encrypt_password
  
  def password
    @password
  end

  def password=(pwd)
    @password = pwd
    create_new_salt
    self.hashed_password = User.encrypted_password(self.password, self.salt)
  end

  def self.authenticate(name,password)
    user = self.find_by_name(name)
    if user
      expected_password = encrypted_password(password, user.salt)
      if user.hashed_password != expected_password
        user = nil
      end
    end
    user
  end

  def safe_delete
    transaction do
      destroy
      if User.count.zero?
        raise "Can't delete last user"
      end
    end
  end

  def role
    case self.level
      when 0
        'netgroup'
      when 1, nil
        'regular user'
    end
  end

#   def encrypt_password
#     if password.present?
#       self.password_salt = BCrypt::Engine.generate_salt
#       self.password_hash = BCrypt::Engine.hash_secret(password, password_salt)
#     end
#   end
  
  private

  def self.encrypted_password(password, salt)
    password.crypt(salt)
  end

  def create_new_salt
    self.salt = (self.object_id.to_s + rand.to_s)[0,2]
  end

end
