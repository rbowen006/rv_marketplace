require 'rails_helper'

RSpec.describe ListingEmbedding do
  let(:listing) { create(:rv_listing) }

  it "persists a 768-dimension embedding for a listing" do
    record = ListingEmbedding.create!(
      rv_listing:   listing,
      embedding:    Array.new(768) { 0.1 },
      document:     "Caravan in Byron Bay, NSW.",
      model:        "nomic-embed-text",
      content_hash: "abc123"
    )

    expect(record.reload.embedding.to_a.length).to eq(768)
  end

  it "ranks embeddings by cosine distance to a query vector" do
    near_vec = [ 1.0 ] + Array.new(767) { 0.0 }
    far_vec  = Array.new(767) { 0.0 } + [ 1.0 ]

    near = ListingEmbedding.create!(rv_listing: create(:rv_listing), embedding: near_vec, model: "nomic-embed-text", content_hash: "a")
    far  = ListingEmbedding.create!(rv_listing: create(:rv_listing), embedding: far_vec, model: "nomic-embed-text", content_hash: "b")

    results = ListingEmbedding.nearest_neighbors(:embedding, near_vec, distance: :cosine).to_a

    expect(results.first).to eq(near)
    expect(results.last).to eq(far)
  end

  it "computes a deterministic content hash for a document" do
    hash_one = ListingEmbedding.content_hash_for("Caravan in Byron Bay, NSW.")
    hash_two = ListingEmbedding.content_hash_for("Caravan in Byron Bay, NSW.")
    other    = ListingEmbedding.content_hash_for("Motorhome in Cairns, QLD.")

    expect(hash_one).to eq(hash_two)
    expect(hash_one).not_to eq(other)
  end

  it "allows only one embedding per listing" do
    ListingEmbedding.create!(rv_listing: listing, embedding: Array.new(768) { 0.1 }, model: "nomic-embed-text", content_hash: "a")

    expect {
      ListingEmbedding.create!(rv_listing: listing, embedding: Array.new(768) { 0.2 }, model: "nomic-embed-text", content_hash: "b")
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
