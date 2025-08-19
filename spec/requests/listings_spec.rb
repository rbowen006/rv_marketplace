require 'rails_helper'

RSpec.describe 'Listings API', type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  describe 'GET /api/v1/listings' do
    it 'returns listings' do
      get '/api/v1/listings'
      expect(response).to have_http_status(:ok)
  ids = JSON.parse(response.body).map { |l| l['id'] }
  expect(ids).to include(listing.id)
    end
  end

  describe 'POST /api/v1/listings' do
    let(:params) { { listing: { title: 'X', description: 'D', location: 'L', price_per_day: 123 } } }

    it 'requires auth' do
      post '/api/v1/listings', params: params.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows owner to create listing' do
      post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token = response.headers['Authorization']&.split(' ')&.last
      expect(token).to be_present

      post '/api/v1/listings', params: params.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['title']).to eq('X')
    end
  end

  describe 'PUT /api/v1/listings/:id' do
    it 'prevents non-owner from updating' do
      post '/users/sign_in', params: { user: { email: other_user.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token = response.headers['Authorization']&.split(' ')&.last

      put "/api/v1/listings/#{listing.id}", params: { listing: { title: 'New' } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows owner to destroy listing and forbids non-owner' do
      # non-owner cannot destroy
      post '/users/sign_in', params: { user: { email: other_user.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token = response.headers['Authorization']&.split(' ')&.last

      delete "/api/v1/listings/#{listing.id}", headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:forbidden)

      # owner can destroy
      post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      owner_token = response.headers['Authorization']&.split(' ')&.last

      delete "/api/v1/listings/#{listing.id}", headers: { 'Authorization' => "Bearer #{owner_token}" }
      expect(response).to have_http_status(:no_content)
    end
  end
end
