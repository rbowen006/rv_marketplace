require 'rails_helper'

RSpec.describe Ai::Tools::SearchListings do
  let(:query_vec) { [1.0] + Array.new(767) { 0.0 } }
  let(:far_vec)   { Array.new(767) { 0.0 } + [1.0] }

  before do
    # This is a search unit test — control the embedding corpus so the assertions
    # see only the listings each example creates. delete_all runs inside the
    # example's transaction (rolled back after), neutralising any rows another
    # spec committed into the shared test DB (see issue #52) without touching them.
    ListingEmbedding.delete_all

    stub_request(:post, "http://ollama:11434/api/embeddings")
      .to_return(status: 200, body: { embedding: query_vec }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def embed!(listing, vector)
    ListingEmbedding.create!(rv_listing: listing, embedding: vector, model: "nomic-embed-text", content_hash: SecureRandom.hex)
  end

  it "returns pruned summaries ranked by semantic similarity" do
    near = create(:rv_listing, title: "Beach van", description: "A" * 300)
    far  = create(:rv_listing, title: "Desert van")
    embed!(near, query_vec)
    embed!(far, far_vec)

    results = described_class.call({ "query" => "beach" })

    expect(results.map { |r| r[:id] }).to eq([near.id, far.id])
    expect(results.first.keys).to match_array(%i[id title town state price_per_day max_guests pet_friendly blurb])
    expect(results.first[:blurb].length).to be <= 200
    expect(results.first).not_to have_key(:description)
  end

  it "filters by state" do
    nsw = create(:rv_listing, state: "NSW")
    vic = create(:rv_listing, state: "VIC")
    embed!(nsw, query_vec)
    embed!(vic, query_vec)

    results = described_class.call({ "query" => "van", "state" => "VIC" })

    expect(results.map { |r| r[:id] }).to eq([vic.id])
  end

  it "filters by minimum guest capacity" do
    small = create(:rv_listing, max_guests: 2)
    big   = create(:rv_listing, max_guests: 6)
    embed!(small, query_vec)
    embed!(big, query_vec)

    results = described_class.call({ "query" => "van", "min_guests" => 4 })

    expect(results.map { |r| r[:id] }).to eq([big.id])
  end

  it "filters by pet_friendly" do
    without = create(:rv_listing, pet_friendly: false)
    with    = create(:rv_listing, pet_friendly: true)
    embed!(without, query_vec)
    embed!(with, query_vec)

    results = described_class.call({ "query" => "van", "pet_friendly" => true })

    expect(results.map { |r| r[:id] }).to eq([with.id])
  end

  it "raises Ai::InputError for a blank query" do
    expect { described_class.call({ "query" => "   " }) }.to raise_error(Ai::InputError)
  end
end
