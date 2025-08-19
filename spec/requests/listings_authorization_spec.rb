require 'rails_helper'

RSpec.describe 'Listings authorization', type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  describe 'POST /api/v1/listings' do
    it 'rejects unauthenticated create' do
      post '/api/v1/listings', params: { listing: { title: 'X', description: 'D', location: 'L', price_per_day: 10 } }.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows authenticated user to create (becomes owner)' do
      headers = auth_header_for(owner)
      post '/api/v1/listings', params: { listing: { title: 'X', description: 'D', location: 'L', price_per_day: 10 } }.to_json, headers: headers
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['user_id']).to eq(owner.id)
    end
  end

  describe 'PUT /api/v1/listings/:id' do
    it 'forbids non-owner' do
      headers = auth_header_for(other_user)
      put "/api/v1/listings/#{listing.id}", params: { listing: { title: 'Changed' } }.to_json, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows owner' do
      headers = auth_header_for(owner)
      put "/api/v1/listings/#{listing.id}", params: { listing: { title: 'Changed' } }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['title']).to eq('Changed')
    end
  end

  describe 'DELETE /api/v1/listings/:id' do
    it 'forbids non-owner' do
      headers = auth_header_for(other_user)
      delete "/api/v1/listings/#{listing.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows owner' do
      headers = auth_header_for(owner)
      delete "/api/v1/listings/#{listing.id}", headers: headers
      expect(response).to have_http_status(:no_content)
    end
  end
end
