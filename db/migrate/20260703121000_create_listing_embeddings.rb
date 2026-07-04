class CreateListingEmbeddings < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :listing_embeddings do |t|
      t.references :rv_listing, null: false, foreign_key: true, index: { unique: true }
      t.vector :embedding, limit: 768
      t.text :document
      t.string :model
      t.string :content_hash

      t.timestamps
    end
  end
end
