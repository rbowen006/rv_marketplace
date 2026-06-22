class RvListing < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :owner, class_name: 'User'
  has_many :bookings, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many_attached :images

  validates :title, :description, :location, :price_per_day, presence: true

  def as_json(options = {})
    super({ only: [ :id, :title, :description, :location, :price_per_day, :owner_id ] }.merge(options)).merge(
      "images" => images.attachments.map { |a| { id: a.id, url: rails_blob_path(a.blob, only_path: true) } }
    )
  end
end
