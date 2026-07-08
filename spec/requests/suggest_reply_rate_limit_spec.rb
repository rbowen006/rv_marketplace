require 'rails_helper'

RSpec.describe 'Suggest Reply rate limiting', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let(:rv_listing) { create(:rv_listing, owner: owner) }
  let(:chat) { create(:chat, owner: owner, hirer: hirer, rv_listing: rv_listing) }
  let(:headers) { auth_header_for(owner) }

  let(:anthropic_success_body) do
    {
      id: "msg_123", type: "message", role: "assistant",
      content: [ { type: "text", text: '{"reply":"Sure thing!"}' } ],
      model: "claude-sonnet-4-6", stop_reason: "end_turn",
      usage: { input_tokens: 10, output_tokens: 5 }
    }.to_json
  end

  before do
    create(:message, chat: chat, user: hirer, content: "Any availability?")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  def suggest(request_headers = headers)
    post "/api/v1/chats/#{chat.id}/suggest_reply", headers: request_headers
  end

  it 'allows 10 suggestions per hour and blocks the 11th' do
    10.times { suggest }
    expect(response).to have_http_status(:ok)

    suggest
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'responds to a throttled request with a JSend fail body and a Retry-After header' do
    11.times { suggest }

    expect(response).to have_http_status(:too_many_requests)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('fail')
    expect(body['message']).to be_present
    expect(response.headers['Retry-After']).to eq(1.hour.to_i.to_s)
  end

  it 'limits per user, so one owner hitting the cap does not affect another' do
    11.times { suggest }
    expect(response).to have_http_status(:too_many_requests)

    other_owner = create(:user)
    other_listing = create(:rv_listing, owner: other_owner)
    other_chat = create(:chat, owner: other_owner, hirer: hirer, rv_listing: other_listing)
    create(:message, chat: other_chat, user: hirer, content: "Hello?")

    post "/api/v1/chats/#{other_chat.id}/suggest_reply", headers: auth_header_for(other_owner)
    expect(response).to have_http_status(:ok)
  end

  it 'does not call Claude for a throttled request' do
    11.times { suggest }
    expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.times(10)
  end
end
