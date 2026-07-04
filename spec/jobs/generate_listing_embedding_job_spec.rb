require 'rails_helper'

RSpec.describe GenerateListingEmbeddingJob, type: :job do
  let(:listing) { create(:rv_listing, rv_type: :caravan, town: 'Byron Bay', state: 'NSW') }
  let(:embedding) { Array.new(768) { 0.02 } }
  let(:ollama_url) { "http://ollama:11434/api/embeddings" }

  before do
    stub_request(:post, ollama_url)
      .to_return(status: 200, body: { embedding: embedding }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "embeds the listing's composed document and stores it" do
    expect {
      described_class.new.perform(listing.id)
    }.to change(ListingEmbedding, :count).by(1)

    record = listing.reload.listing_embedding
    expect(record.embedding.to_a.length).to eq(768)
    expect(record.document).to eq(listing.embedding_document)
    expect(record.model).to eq("nomic-embed-text")
    expect(record.content_hash).to eq(ListingEmbedding.content_hash_for(listing.embedding_document))
  end

  it "does not re-embed when the composed document is unchanged" do
    described_class.new.perform(listing.id)

    expect {
      described_class.new.perform(listing.id)
    }.not_to change { listing.reload.listing_embedding.updated_at }

    expect(a_request(:post, ollama_url)).to have_been_made.once
  end

  it "re-embeds when the listing's document changes" do
    described_class.new.perform(listing.id)
    listing.update!(title: "A brand new headline")

    described_class.new.perform(listing.id)

    expect(a_request(:post, ollama_url)).to have_been_made.twice
    expect(listing.reload.listing_embedding.document).to include("A brand new headline")
  end

  it "does nothing when the listing no longer exists" do
    expect {
      described_class.new.perform(-1)
    }.not_to change(ListingEmbedding, :count)

    expect(a_request(:post, ollama_url)).not_to have_been_made
  end
end
