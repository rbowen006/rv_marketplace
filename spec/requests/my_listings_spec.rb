require 'rails_helper'

RSpec.describe 'My Listings API', type: :request do
  let(:owner) { create(:user) }

  describe 'GET /api/v1/listings/mine' do
    it 'requires auth' do
      get '/api/v1/listings/mine'
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns only the current owner's listings" do
      mine     = create(:rv_listing, owner: owner)
      other    = create(:rv_listing, owner: create(:user))

      get '/api/v1/listings/mine', headers: { 'Authorization' => "Bearer #{auth_token_for(owner)}" }

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |l| l['id'] }
      expect(ids).to include(mine.id)
      expect(ids).not_to include(other.id)
    end

    it 'returns an empty array when the owner has no listings' do
      get '/api/v1/listings/mine', headers: { 'Authorization' => "Bearer #{auth_token_for(owner)}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end
end
