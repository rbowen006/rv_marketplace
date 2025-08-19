require 'rails_helper'

RSpec.describe 'Bookings authorization', type: :request do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let!(:listing) { create(:rv_listing, user: owner) }

  describe 'POST /api/v1/listings/:listing_id/bookings' do
    let(:params) { { booking: { start_date: Date.today + 1, end_date: Date.today + 3 } } }

    it 'rejects unauthenticated' do
      post "/api/v1/listings/#{listing.id}/bookings", params: params.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids owner from booking their own listing' do
      headers = auth_header_for(owner)
      post "/api/v1/listings/#{listing.id}/bookings", params: params.to_json, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows hirer to create booking' do
      headers = auth_header_for(hirer)
      post "/api/v1/listings/#{listing.id}/bookings", params: params.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/v1/bookings/:id/confirm and reject' do
    let(:booking) { create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 1, end_date: Date.today + 3) }

    it 'forbids non-owner from confirming' do
      headers = auth_header_for(hirer)
      patch "/api/v1/bookings/#{booking.id}/confirm", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows owner to confirm' do
      headers = auth_header_for(owner)
      patch "/api/v1/bookings/#{booking.id}/confirm", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('confirmed')
    end

    it 'allows owner to reject' do
      # Create a fresh booking
      b = create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 5, end_date: Date.today + 7)
      headers = auth_header_for(owner)
      patch "/api/v1/bookings/#{b.id}/reject", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('rejected')
    end
  end
end
