require 'rails_helper'

RSpec.describe 'Suggest Reply API', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let(:rv_listing) { create(:rv_listing, owner: owner) }
  let(:chat) { create(:chat, owner: owner, hirer: hirer, rv_listing: rv_listing) }
  let(:headers) { auth_header_for(owner) }

  let(:anthropic_success_body) do
    {
      id: "msg_123", type: "message", role: "assistant",
      content: [ { type: "text", text: '{"reply":"Yes, it sleeps four comfortably."}' } ],
      model: "claude-sonnet-4-6", stop_reason: "end_turn",
      usage: { input_tokens: 150, output_tokens: 15 }
    }.to_json
  end

  before do
    create(:message, chat: chat, user: hirer, content: "How many does it sleep?")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  def suggest(chat_record = chat, request_headers = headers)
    post "/api/v1/chats/#{chat_record.id}/suggest_reply", headers: request_headers
  end

  describe 'POST /api/v1/chats/:id/suggest_reply' do
    it 'returns a suggested reply as JSend success for the owner' do
      suggest
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('success')
      expect(body['data']['reply']).to eq('Yes, it sleeps four comfortably.')
    end

    it 'requires authentication' do
      post "/api/v1/chats/#{chat.id}/suggest_reply"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids the hirer from suggesting a reply (owner only)' do
      suggest(chat, auth_header_for(hirer))
      expect(response).to have_http_status(:forbidden)
      expect(a_request(:post, "https://api.anthropic.com/v1/messages")).not_to have_been_made
    end

    it 'returns 404 for a chat that does not exist' do
      post "/api/v1/chats/0/suggest_reply", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 when the thread has no hirer message to reply to' do
      other_hirer = create(:user)
      quiet_chat = create(:chat, owner: owner, hirer: other_hirer, rv_listing: rv_listing)
      create(:message, chat: quiet_chat, user: owner, content: "Hi, are you still interested?")

      suggest(quiet_chat)
      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('fail')
      expect(a_request(:post, "https://api.anthropic.com/v1/messages")).not_to have_been_made
    end

    it 'returns JSend error with 503 when Claude is unavailable' do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 529, body: '{"error":{"type":"overloaded_error","message":"Overloaded"}}',
                   headers: { "Content-Type" => "application/json" })

      suggest
      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)['status']).to eq('error')
    end
  end
end
