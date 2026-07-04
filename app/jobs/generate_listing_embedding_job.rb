class GenerateListingEmbeddingJob < ApplicationJob
  queue_as :default

  # Regenerates a listing's semantic-search embedding (ADR-0011). Idempotent:
  # re-embeds only when the composed document is missing or its content_hash
  # changed, so edits to fields outside the document (price, lat/lng) are
  # no-ops and the job is safe to re-run.
  def perform(rv_listing_id)
    listing = RvListing.find_by(id: rv_listing_id)
    return unless listing

    document = listing.embedding_document
    content_hash = ListingEmbedding.content_hash_for(document)

    record = ListingEmbedding.find_or_initialize_by(rv_listing_id: listing.id)
    return if record.persisted? && record.content_hash == content_hash

    embedding = Ai::Embedder.call(document, feature: "listing_embedding")

    record.update!(
      embedding:    embedding,
      document:     document,
      model:        Ai::Embedder::MODEL,
      content_hash: content_hash
    )
  end
end
