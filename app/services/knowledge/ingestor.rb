module Knowledge
  # Embeds one region's markdown corpus into KnowledgeChunks (ADR-0013), the
  # heart of the deploy-time `knowledge:embed` task. Idempotent on content_hash:
  # unchanged sections are skipped (no paid/again embed call), and chunks whose
  # section changed or was removed are pruned. Returns the number of live chunks.
  class Ingestor
    EMBED_FEATURE = "trip_knowledge"

    def self.call(region:, markdown:)
      new(region: region, markdown: markdown).call
    end

    def initialize(region:, markdown:)
      @region   = region
      @markdown = markdown
    end

    def call
      seen_hashes = DocumentChunker.call(@markdown).map { |chunk| upsert(chunk) }
      prune_stale(seen_hashes)
      seen_hashes.size
    end

    private

    def upsert(chunk)
      hash   = KnowledgeChunk.content_hash_for(region: @region, heading: chunk[:heading], content: chunk[:content])
      record = KnowledgeChunk.find_or_initialize_by(region: @region, content_hash: hash)
      return hash if record.persisted?

      record.update!(
        heading:   chunk[:heading],
        content:   chunk[:content],
        embedding: Ai::Embedder.call(embed_text(chunk), feature: EMBED_FEATURE),
        model:     Ai::Embedder::MODEL
      )
      hash
    end

    # Embed heading + body together so a section's topic informs its vector.
    def embed_text(chunk)
      [ chunk[:heading], chunk[:content] ].compact.join("\n\n")
    end

    def prune_stale(seen_hashes)
      KnowledgeChunk.where(region: @region).where.not(content_hash: seen_hashes).delete_all
    end
  end
end
