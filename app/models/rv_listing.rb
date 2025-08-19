class RvListing < ApplicationRecord
  belongs_to :user
    has_many :bookings, dependent: :destroy
    has_many :messages, dependent: :destroy

    validates :title, :description, :location, :price_per_day, presence: true

    def as_json(options = {})
      super({ only: [:id, :title, :description, :location, :price_per_day, :user_id] }.merge(options))
    end
  end
