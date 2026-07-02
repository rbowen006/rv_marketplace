require 'rails_helper'

RSpec.describe 'Malformed JSON request bodies', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_header_for(user) }

  it 'returns a JSend fail response, not a raw error page, for a malformed body on an Api::V1 endpoint' do
    post '/api/v1/listings/generate_description',
         params: '{"rv_type":"motorhome", BROKEN',
         headers: headers.merge('Content-Type' => 'application/json')

    expect(response).to have_http_status(:bad_request)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('fail')
  end

  it 'returns a JSend fail response for a malformed body on a Devise (non-Api::V1) endpoint' do
    post '/users/sign_in',
         params: '{"user":{"email": BROKEN',
         headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:bad_request)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('fail')
  end
end
