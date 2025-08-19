require 'rails_helper'

RSpec.describe 'Messages API', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  it 'allows authenticated users to post messages on a listing' do
    post '/users/sign_in', params: { user: { email: hirer.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    token = response.headers['Authorization']&.split(' ')&.last

    post "/api/v1/listings/#{listing.id}/messages", params: { message: { content: 'Hello' } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['content']).to eq('Hello')
  end

  it 'prevents unauthenticated users from posting messages' do
    post "/api/v1/listings/#{listing.id}/messages", params: { message: { content: 'Hi' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'allows owner to list messages and sees new messages from hirer' do
    # hirer posts a message
    post '/users/sign_in', params: { user: { email: hirer.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    hirer_token = response.headers['Authorization']&.split(' ')&.last

    post "/api/v1/listings/#{listing.id}/messages", params: { message: { content: 'Is this available?' } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{hirer_token}" }
    expect(response).to have_http_status(:created)

    # owner signs in and lists messages
    post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    owner_token = response.headers['Authorization']&.split(' ')&.last

    get "/api/v1/listings/#{listing.id}/messages", headers: { 'Authorization' => "Bearer #{owner_token}" }
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.any? { |m| m['content'] == 'Is this available?' }).to be true
  end

  it 'prevents unauthenticated users from listing messages' do
    get "/api/v1/listings/#{listing.id}/messages"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns unprocessable for empty message content' do
    post '/users/sign_in', params: { user: { email: hirer.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    token = response.headers['Authorization']&.split(' ')&.last

    post "/api/v1/listings/#{listing.id}/messages", params: { message: { content: '' } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
