require 'rails_helper'

RSpec.describe 'Chats API', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let!(:listing) { create(:rv_listing, owner: owner) }

  def hirer_token
    post '/users/sign_in', params: { user: { email: hirer.email, password: 'password' } }.to_json,
         headers: { 'Content-Type' => 'application/json' }
    response.headers['Authorization']&.split(' ')&.last
  end

  def owner_token
    post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json,
         headers: { 'Content-Type' => 'application/json' }
    response.headers['Authorization']&.split(' ')&.last
  end

  describe 'POST /api/v1/listings/:id/chats' do
    it 'creates a chat and first message when none exists' do
      post "/api/v1/listings/#{listing.id}/chats",
           params: { message: { content: 'Is this available in July?' } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{hirer_token}" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['hirer_id']).to eq(hirer.id)
      expect(body['owner_id']).to eq(owner.id)
      expect(body['rv_listing_id']).to eq(listing.id)
      expect(body['messages'].first['content']).to eq('Is this available in July?')
    end

    it 'returns an existing unbooked chat and updates the subject when one already exists' do
      existing_chat = create(:chat, hirer: hirer, owner: owner, rv_listing: listing)
      other_listing = create(:rv_listing, owner: owner)

      post "/api/v1/listings/#{other_listing.id}/chats",
           params: { message: { content: 'What about this one?' } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{hirer_token}" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(existing_chat.id)
      expect(body['rv_listing_id']).to eq(other_listing.id)
      expect(body['messages'].last['content']).to eq('What about this one?')
    end

    it 'blocks unauthenticated requests' do
      post "/api/v1/listings/#{listing.id}/chats",
           params: { message: { content: 'Hello' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/chats/:id/messages' do
    let!(:chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }

    it 'allows the hirer to send a message in the chat' do
      post "/api/v1/chats/#{chat.id}/messages",
           params: { message: { content: 'Any chance of a discount?' } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{hirer_token}" }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['content']).to eq('Any chance of a discount?')
    end

    it 'allows the owner to reply' do
      post "/api/v1/chats/#{chat.id}/messages",
           params: { message: { content: 'Sure, 10% off for you!' } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{owner_token}" }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['content']).to eq('Sure, 10% off for you!')
    end

    it 'blocks a third party from sending a message' do
      outsider = create(:user)
      post '/users/sign_in', params: { user: { email: outsider.email, password: 'password' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      outsider_token = response.headers['Authorization']&.split(' ')&.last

      post "/api/v1/chats/#{chat.id}/messages",
           params: { message: { content: 'I am not in this chat' } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{outsider_token}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/chats/:id/messages' do
    let!(:chat) { create(:chat, hirer: hirer, owner: owner, rv_listing: listing) }
    let!(:msg) { create(:message, chat: chat, user: hirer) }

    it 'allows the hirer to list messages' do
      get "/api/v1/chats/#{chat.id}/messages",
          headers: { 'Authorization' => "Bearer #{hirer_token}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |m| m['id'] }).to include(msg.id)
    end

    it 'allows the owner to list messages' do
      get "/api/v1/chats/#{chat.id}/messages",
          headers: { 'Authorization' => "Bearer #{owner_token}" }

      expect(response).to have_http_status(:ok)
    end

    it 'blocks unauthenticated requests' do
      get "/api/v1/chats/#{chat.id}/messages"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
