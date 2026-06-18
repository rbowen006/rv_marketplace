class RvListing < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :owner, class_name: 'User'
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many_attached :images

  validates :title, :description, :location, :price_per_day, presence: true

  def as_json(options = {})
    super({ only: [ :id, :title, :description, :location, :price_per_day, :owner_id ] }.merge(options)).merge(
      "image_urls" => images.map { |img| rails_blob_path(img) }
    )
  end
end
