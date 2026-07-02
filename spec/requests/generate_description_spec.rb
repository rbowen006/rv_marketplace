require 'rails_helper'

RSpec.describe 'Generate Description API', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_header_for(user) }

  let(:valid_params) do
    {
      rv_type: "caravan",
      town: "Byron Bay",
      state: "NSW",
      max_guests: 4,
      pet_friendly: true,
      price_per_day: 180
    }
  end

  let(:anthropic_success_body) do
    {
      id: "msg_123", type: "message", role: "assistant",
      content: [ { type: "text", text: '{"description":"A stunning caravan in Byron Bay."}' } ],
      model: "claude-sonnet-4-6", stop_reason: "end_turn",
      usage: { input_tokens: 120, output_tokens: 30 }
    }.to_json
  end

  before do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  describe 'POST /api/v1/listings/generate_description' do
    it 'requires authentication' do
      post '/api/v1/listings/generate_description', params: valid_params.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns a generated description as JSend success' do
      post '/api/v1/listings/generate_description', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('success')
      expect(body['data']['description']).to eq('A stunning caravan in Byron Bay.')
    end

    it 'returns JSend fail when a required field is missing' do
      post '/api/v1/listings/generate_description',
           params: valid_params.except(:rv_type).to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('fail')
    end

    it 'returns JSend error when Claude API fails' do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 529, body: '{"error":{"type":"overloaded_error","message":"Overloaded"}}',
                   headers: { "Content-Type" => "application/json" })

      post '/api/v1/listings/generate_description', params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('error')
    end
  end
end
