require 'rails_helper'

RSpec.describe 'Concierge API', type: :request do
  let(:user) { create(:user) }
  let(:json) { JSON.parse(response.body) }

  before { allow(ConciergeTurnJob).to receive(:perform_later) }

  describe 'GET /api/v1/concierge' do
    it 'requires authentication' do
      get '/api/v1/concierge'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns a "none" empty state when the user has no conversation' do
      get '/api/v1/concierge', headers: auth_header_for(user)

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'status')).to eq('none')
    end

    it 'returns display messages and hydrated recommendations from the transcript' do
      listing = create(:rv_listing, title: 'Beach van')
      ConciergeConversation.create!(user: user, status: :idle, transcript: [
        { 'role' => 'user', 'content' => 'find me a van' },
        { 'role' => 'assistant', 'content' => [
          { 'type' => 'text', 'text' => 'Here is a great option.' },
          { 'type' => 'tool_use', 'id' => 't1', 'name' => 'recommend_listings',
            'input' => { 'listing_ids' => [listing.id] } }
        ] }
      ])

      get '/api/v1/concierge', headers: auth_header_for(user)

      expect(response).to have_http_status(:ok)
      messages = json.dig('data', 'messages')
      expect(messages).to eq([
        { 'role' => 'user', 'text' => 'find me a van' },
        { 'role' => 'assistant', 'text' => 'Here is a great option.' }
      ])
      recs = json.dig('data', 'recommendations')
      expect(recs.map { |r| r['id'] }).to eq([listing.id])
      expect(recs.first['title']).to eq('Beach van')
    end
  end

  describe 'POST /api/v1/concierge/messages' do
    it 'appends the user message, moves to processing, and enqueues a turn' do
      post '/api/v1/concierge/messages',
           params: { message: 'find me a pet-friendly van' }.to_json,
           headers: auth_header_for(user)

      expect(response).to have_http_status(:accepted)
      expect(json.dig('data', 'status')).to eq('processing')

      conversation = user.reload.concierge_conversation
      expect(conversation).to be_processing
      expect(conversation.transcript.last).to eq({ 'role' => 'user', 'content' => 'find me a pet-friendly van' })
      expect(ConciergeTurnJob).to have_received(:perform_later).with(conversation.id)
    end

    it 'rejects a blank message with 400' do
      post '/api/v1/concierge/messages', params: { message: '  ' }.to_json, headers: auth_header_for(user)
      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects an over-long message with 400' do
      post '/api/v1/concierge/messages', params: { message: 'x' * 1501 }.to_json, headers: auth_header_for(user)
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 409 while a turn is already processing' do
      ConciergeConversation.create!(user: user, status: :processing)

      post '/api/v1/concierge/messages', params: { message: 'hello again' }.to_json, headers: auth_header_for(user)

      expect(response).to have_http_status(:conflict)
      expect(ConciergeTurnJob).not_to have_received(:perform_later)
    end
  end

  describe 'DELETE /api/v1/concierge' do
    it 'resets the conversation' do
      ConciergeConversation.create!(user: user, status: :idle, transcript: [{ 'role' => 'user', 'content' => 'hi' }])

      delete '/api/v1/concierge', headers: auth_header_for(user)

      expect(response).to have_http_status(:ok)
      expect(user.reload.concierge_conversation).to be_nil
    end
  end
end
