class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null

  # Associations for marketplace roles
  # A user can be an owner (has many listings) and/or a hirer (creates bookings/messages)
  has_many :rv_listings, foreign_key: :owner_id, dependent: :destroy
  has_many :bookings, foreign_key: :hirer_id, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_one :concierge_conversation, dependent: :destroy
  has_one_attached :avatar

  validates :name, presence: true
end
