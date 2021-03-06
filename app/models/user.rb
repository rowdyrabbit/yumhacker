class User < ActiveRecord::Base
  devise :database_authenticatable, :lockable, :registerable,
        :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :omniauth_providers => [:facebook, :twitter]

  has_many :relationships, :foreign_key => 'follower_id', :dependent => :destroy
  has_many :followed_users, :through => :relationships, :source => :followed

  has_many :reverse_relationships, :foreign_key => 'followed_id', :class_name => 'Relationship', :dependent => :destroy
  has_many :followers, :through => :reverse_relationships, :source => :follower

  has_many :endorsements, :dependent => :destroy
  has_many :establishments, :through => :endorsements

  has_many :comments, :dependent => :destroy
  has_many :photos, :dependent => :destroy

  has_attached_file :avatar, :styles => { :medium => "200x200#", :small => "100x100#", :thumb => "30x30#" }, :default_url => "/missing.png"

  def following?(id)
    relationships.where(:followed_id => id).count > 0
  end

  def follow!(ids)
    relationships.create!(:followed_id => ids)
  end

  def follow_all!(ids)
    ids -= [User.first.id.to_s, self.id.to_s]
    ids.map!{ |id| { followed_id: id }}
    relationships.create!(ids)
  end

  def unfollow!(id)
    relationships.where(:followed_id => id).first.try(:destroy)
  end

  def endorsing?(id)
    endorsements.where(:establishment_id => id).count > 0
  end

  def endorse!(id)
    endorsements.create!(:establishment_id => id)
  end

  def unendorse!(id)
    endorsements.where(:establishment_id => id).first.try(:destroy)
  end

  def path
    'users/' + id.to_s.parameterize
  end

  def get_fb_friends_on_yumhacker
    @graph = Koala::Facebook::API.new(token)
    fb_friends = @graph.get_connections("me", "friends")
    uids = []
    fb_friends.each { |friend| uids.push(friend['id']) }

    return User.where(:uid => uids, :provider => 'facebook')
  end

  def store_fb_friends_in_redis(friends)
    $redis.sadd('user:' + id.to_s, friends)
  end

  def get_fb_friends_from_redis
    $redis.smembers('user:' + id.to_s)
  end

  def remove_fb_friends_from_redis
    $redis.del('user:' + id.to_s)
  end

  def automatic_relationships!
    jen = User.first
    follow!(jen.id);
    jen.follow!(id)
  end

end
