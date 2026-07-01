class RvListing < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :owner, class_name: 'User'
  has_many :bookings, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many_attached :images

  enum :rv_type, { caravan: 0, motorhome: 1, camper_trailer: 2 }

  validates :title, :description, :rv_type, :town, :state, :postcode, :price_per_day, :max_guests, presence: true
  validate :at_least_one_image, on: :create

  private

  def at_least_one_image
    errors.add(:images, "must have at least one photo") unless images.attached?
  end

  public

  def as_json(options = {})
    super({ only: [ :id, :title, :description, :rv_type, :town, :state, :postcode, :price_per_day, :owner_id, :max_guests, :pet_friendly, :latitude, :longitude ] }.merge(options)).merge(
      "owner" => { "id" => owner_id, "name" => owner.name },
      "images" => images.attachments.map { |a| { id: a.id, url: rails_blob_path(a.blob, only_path: true) } }
    )
  end
end
