require 'rails_helper'

RSpec.describe 'Bookings edge cases', type: :request do
  let(:owner) { create(:user) }
  let(:hirer1) { create(:user) }
  let(:hirer2) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  context 'concurrent booking attempts' do
    it 'prevents overlapping when two hirers try to book the same dates' do
      # hirer1 creates a booking first
      post '/users/sign_in', params: { user: { email: hirer1.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token1 = response.headers['Authorization']&.split(' ')&.last

      expect(token1).to be_present
      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 5, end_date: Date.today + 7 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token1}" }
      expect(response).to have_http_status(:created)

      # hirer2 attempts to create overlapping booking
      post '/users/sign_in', params: { user: { email: hirer2.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token2 = response.headers['Authorization']&.split(' ')&.last
      expect(token2).to be_present

      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 6, end_date: Date.today + 8 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token2}" }
      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body['errors'].any? { |e| e.match(/overlap/) }).to be true
    end

    it 'handles rapid sequential requests where second arrives immediately after first' do
      # Simulate near-concurrent by creating first then immediately attempting second
      post '/users/sign_in', params: { user: { email: hirer1.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token1 = response.headers['Authorization']&.split(' ')&.last
      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 10, end_date: Date.today + 12 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token1}" }
      expect(response).to have_http_status(:created)

      # Immediately attempt to create an overlapping booking as another user
      post '/users/sign_in', params: { user: { email: hirer2.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token2 = response.headers['Authorization']&.split(' ')&.last
      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Date.today + 12, end_date: Date.today + 14 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token2}" }

      # According to current logic, start_date equal to existing end_date counts as overlap
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'timezone handling' do
    around do |example|
      old_zone = Time.zone
      example.run
      Time.zone = old_zone
    end

    it 'detects overlap correctly across different Time.zone settings' do
      Time.zone = 'Pacific Time (US & Canada)'
      post '/users/sign_in', params: { user: { email: hirer1.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token1 = response.headers['Authorization']&.split(' ')&.last
      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Time.zone.today + 2, end_date: Time.zone.today + 4 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token1}" }
      expect(response).to have_http_status(:created)

      Time.zone = 'UTC'
      post '/users/sign_in', params: { user: { email: hirer2.email, password: 'password' } }.to_json, headers: { 'Content-Type' => 'application/json' }
      token2 = response.headers['Authorization']&.split(' ')&.last
      post "/api/v1/listings/#{listing.id}/bookings", params: { booking: { start_date: Time.zone.today + 3, end_date: Time.zone.today + 5 } }.to_json, headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token2}" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
