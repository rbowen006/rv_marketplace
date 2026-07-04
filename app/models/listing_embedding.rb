class ListingEmbedding < ApplicationRecord
  belongs_to :rv_listing
  has_neighbors :embedding

  # SHA256 of the composed document, used to skip re-embedding when a listing
  # edit did not change the embedded text (ADR-0011).
  def self.content_hash_for(document)
    Digest::SHA256.hexdigest(document)
  end
end
