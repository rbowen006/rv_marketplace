class CreateKnowledgeChunks < ActiveRecord::Migration[8.0]
  # Trip-planning RAG corpus, embedded at deploy time (ADR-0013). One row per
  # H2 section of a region's markdown; region is the manifest slug (no FK, since
  # Region is a config manifest, not a table). content_hash makes re-embedding
  # idempotent, mirroring listing_embeddings.
  def change
    create_table :knowledge_chunks do |t|
      t.string :region, null: false
      t.string :heading
      t.text :content, null: false
      t.vector :embedding, limit: 768
      t.string :model
      t.string :content_hash, null: false

      t.timestamps
    end

    add_index :knowledge_chunks, :region
    add_index :knowledge_chunks, [ :region, :content_hash ], unique: true
  end
end
