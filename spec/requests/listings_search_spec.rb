require 'rails_helper'

RSpec.describe 'Listings semantic search', type: :request do
  let(:query_vec) { [ 1.0 ] + Array.new(767) { 0.0 } }
  let(:far_vec)   { Array.new(767) { 0.0 } + [ 1.0 ] }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  before do
    stub_request(:post, "http://ollama:11434/api/embeddings")
      .to_return(status: 200, body: { embedding: query_vec }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def embed!(listing, vector)
    ListingEmbedding.create!(rv_listing: listing, embedding: vector, model: 'nomic-embed-text', content_hash: SecureRandom.hex)
  end

  describe 'POST /api/v1/listings/search' do
    it 'is public and returns listings ranked by semantic similarity, each with a score' do
      near = create(:rv_listing, title: 'Beachfront caravan')
      far  = create(:rv_listing, title: 'Desert motorhome')
      embed!(near, query_vec)
      embed!(far, far_vec)

      post '/api/v1/listings/search', params: { query: 'caravan by the sea' }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |l| l['id'] }).to eq([ near.id, far.id ])
      expect(body.first).to include('title', 'rv_type', 'owner', 'images', 'score')
      expect(body.first['id']).to eq(near.id)
    end

    it 'returns at most 20 results' do
      25.times { |i| embed!(create(:rv_listing), query_vec) }

      post '/api/v1/listings/search', params: { query: 'anything' }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(20)
    end

    it 'returns 422 when the query is blank' do
      post '/api/v1/listings/search', params: { query: '  ' }.to_json, headers: json_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 503 when the embedding service is unavailable' do
      stub_request(:post, "http://ollama:11434/api/embeddings").to_return(status: 500, body: 'down')

      post '/api/v1/listings/search', params: { query: 'caravan' }.to_json, headers: json_headers

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'logs the query embedding to ai_requests under the nl_search feature' do
      embed!(create(:rv_listing), query_vec)

      expect {
        post '/api/v1/listings/search', params: { query: 'caravan' }.to_json, headers: json_headers
      }.to change { AiRequest.where(feature: 'nl_search').count }.by(1)
    end
  end
end
