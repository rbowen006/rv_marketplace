require 'rails_helper'

RSpec.describe 'Bookings API', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  it 'prevents owner from creating booking on own listing' do
    post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    token = response.headers['Authorization']&.split(' ')&.last

    post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 1, end_date: Date.today + 3 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
    expect(response).to have_http_status(:forbidden)
  end

  it 'allows hirer to create booking and owner to confirm' do
    # hirer creates booking
    post '/users/sign_in', params: { user: { email: hirer.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    hirer_token = response.headers['Authorization']&.split(' ')&.last

    post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 1, end_date: Date.today + 3 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{hirer_token}" }
    expect(response).to have_http_status(:created)
    booking_id = JSON.parse(response.body)['id']

    # owner confirms
    post '/users/sign_in', params: { user: { email: owner.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
    owner_token = response.headers['Authorization']&.split(' ')&.last

    patch "/api/v1/bookings/#{booking_id}/confirm", headers: { 'Authorization' => "Bearer #{owner_token}" }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['status']).to eq('confirmed')
  end
end
