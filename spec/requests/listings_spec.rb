require 'rails_helper'

RSpec.describe 'Listings API', type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:listing) { create(:rv_listing, owner: owner) }

  describe 'GET /api/v1/listings' do
    it 'returns listings' do
      get '/api/v1/listings'
      expect(response).to have_http_status(:ok)
  ids = JSON.parse(response.body).map { |l| l['id'] }
  expect(ids).to include(listing.id)
    end
  end

  describe 'POST /api/v1/listings' do
    let(:valid_params) do
      { listing: { title: 'Cozy Caravan', description: 'A lovely caravan', rv_type: 'caravan',
                   town: 'Byron Bay', state: 'NSW', postcode: '2481',
                   price_per_day: 150, max_guests: 4,
                   images: [ fixture_file_upload('test.png', 'image/png') ] } }
    end

    it 'requires auth' do
      post '/api/v1/listings', params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end

    it 'owner can create a listing with rv_type, town, state and postcode' do
      post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token = response.headers['Authorization']&.split(' ')&.last

      post '/api/v1/listings', params: valid_params, headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['title']).to eq('Cozy Caravan')
      expect(body['rv_type']).to eq('caravan')
      expect(body['town']).to eq('Byron Bay')
      expect(body['state']).to eq('NSW')
      expect(body['postcode']).to eq('2481')
    end

    it 'returns 422 when required fields are missing' do
      post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token = response.headers['Authorization']&.split(' ')&.last

      post '/api/v1/listings', params: { listing: { title: 'X' } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PUT /api/v1/listings/:id' do
    it 'does not remove attached images when updating other fields' do
      listing.images.attach(fixture_file_upload('test.png', 'image/png'))
      expect(listing.images.count).to eq(2)

      put "/api/v1/listings/#{listing.id}",
          params: { listing: { title: 'Updated Title' } }.to_json,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{auth_token_for(owner)}" }

      expect(response).to have_http_status(:ok)
      expect(listing.reload.images.count).to eq(2)
    end

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
