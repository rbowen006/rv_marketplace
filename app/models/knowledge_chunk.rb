# A retrievable unit of trip-planning knowledge (ADR-0013): one H2 section of a
# Region's markdown corpus, embedded for nearest-neighbour retrieval. `region`
# is the Region manifest slug (Region is config, not a table, so no FK).
class KnowledgeChunk < ApplicationRecord
  has_neighbors :embedding

  DEFAULT_LIMIT = 6

  # Top-k chunks within one region, nearest first (ADR-0013). Returns a
  # materialised array — never a live nearest_neighbors relation, whose reversed
  # ORDER BY makes .last/.reverse silently wrong (see reference_neighbor_last_gotcha).
  def self.retrieve(region:, query_embedding:, limit: DEFAULT_LIMIT)
    where(region: region)
      .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
      .limit(limit)
      .to_a
  end

  # SHA256 of "region\nheading\ncontent", used to skip re-embedding unchanged
  # sections (mirrors ListingEmbedding, ADR-0011).
  def self.content_hash_for(region:, heading:, content:)
    Digest::SHA256.hexdigest([ region, heading, content ].join("\n"))
  end
end
