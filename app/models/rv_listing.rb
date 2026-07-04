class RvListing < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :owner, class_name: 'User'
  has_many :bookings, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_one :listing_embedding, dependent: :destroy
  has_many_attached :images

  enum :rv_type, { caravan: 0, motorhome: 1, camper_trailer: 2 }

  validates :title, :description, :rv_type, :town, :state, :postcode, :price_per_day, :max_guests, presence: true
  validate :at_least_one_image, on: :create

  # Refresh the semantic-search embedding whenever listing content changes
  # (ADR-0011). The callback stays dumb — the job decides whether a re-embed is
  # actually needed (idempotent on content_hash).
  after_commit :refresh_embedding, on: [ :create, :update ]

  private

  def at_least_one_image
    errors.add(:images, "must have at least one photo") unless images.attached?
  end

  def refresh_embedding
    GenerateListingEmbeddingJob.perform_later(id)
  end

  public

  # The composed text embedded for semantic search (ADR-0011): structured
  # fields rendered as prose, then the free text. Price is deliberately
  # excluded — "cheap"/"under $200" is served by a future hard filter, not
  # semantic proximity.
  def embedding_document
    parts = []
    parts << "#{rv_type.to_s.humanize} in #{town}, #{state}."
    parts << "Sleeps #{max_guests} guests." if max_guests.present?
    parts << "Pet-friendly." if pet_friendly?
    parts << "#{title}."
    parts << description.to_s
    parts.join(" ").strip
  end

  def as_json(options = {})
    super({ only: [ :id, :title, :description, :rv_type, :town, :state, :postcode, :price_per_day, :owner_id, :max_guests, :pet_friendly, :latitude, :longitude ] }.merge(options)).merge(
      "owner" => { "id" => owner_id, "name" => owner.name },
      "images" => images.attachments.map { |a| { id: a.id, url: rails_blob_path(a.blob, only_path: true) } }
    )
  end
end
