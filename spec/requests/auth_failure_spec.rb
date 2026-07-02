require 'rails_helper'

RSpec.describe 'Unauthenticated requests to protected endpoints', type: :request do
  it 'returns a JSend fail response, not Devise\'s default {error: ...} shape' do
    post '/api/v1/listings/generate_description',
         params: { rv_type: 'motorhome' }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('fail')
    expect(body['message']).to be_present
  end

  it 'does not use Devise\'s default bare {error: ...} shape' do
    post '/api/v1/listings/generate_description',
         params: { rv_type: 'motorhome' }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }

    body = JSON.parse(response.body)
    expect(body.keys).not_to eq(['error'])
  end
end
