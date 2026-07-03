require 'rails_helper'

RSpec.describe 'Generate Description rate limiting', type: :request do
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
      content: [ { type: "text", text: '{"description":"A caravan in Byron Bay."}' } ],
      model: "claude-sonnet-4-6", stop_reason: "end_turn",
      usage: { input_tokens: 10, output_tokens: 5 }
    }.to_json
  end

  before do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  def generate(request_headers = headers)
    post '/api/v1/listings/generate_description', params: valid_params.to_json, headers: request_headers
  end

  it 'allows 10 generations per hour and blocks the 11th' do
    10.times { generate }
    expect(response).to have_http_status(:ok)

    generate
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'responds to a throttled request with a JSend fail body and a Retry-After header' do
    11.times { generate }

    expect(response).to have_http_status(:too_many_requests)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('fail')
    expect(body['message']).to be_present
    expect(response.headers['Retry-After']).to eq(1.hour.to_i.to_s)
  end

  it 'limits per user, so one user hitting the cap does not affect another' do
    11.times { generate }
    expect(response).to have_http_status(:too_many_requests)

    other_user = create(:user)
    generate(auth_header_for(other_user))
    expect(response).to have_http_status(:ok)
  end

  it 'does not call Claude for a throttled request' do
    11.times { generate }

    # Only the 10 admitted requests reach Anthropic; the throttled 11th does not.
    expect(a_request(:post, "https://api.anthropic.com/v1/messages")).to have_been_made.times(10)
  end

  it 'counts input-validation failures against the limit' do
    # The limiter increments on admission, before validation. Ten bad-input
    # requests (each a 400) exhaust the window; the 11th is throttled, not a 400.
    invalid = valid_params.except(:rv_type)
    10.times do
      post '/api/v1/listings/generate_description', params: invalid.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    post '/api/v1/listings/generate_description', params: invalid.to_json, headers: headers
    expect(response).to have_http_status(:too_many_requests)
  end
end
