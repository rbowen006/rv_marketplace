require 'rails_helper'

RSpec.describe 'Booking show', type: :request do
  let(:owner)  { create(:user) }
  let(:hirer)  { create(:user) }
  let(:listing) { create(:rv_listing, owner: owner) }
  let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, status: 'confirmed') }

  it 'returns the booking to its hirer' do
    get "/api/v1/bookings/#{booking.id}", headers: auth_header_for(hirer)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['id']).to eq(booking.id)
    expect(body['status']).to eq('confirmed')
  end

  it 'returns the booking to the listing owner' do
    get "/api/v1/bookings/#{booking.id}", headers: auth_header_for(owner)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['id']).to eq(booking.id)
  end

  it 'does not reveal the booking to a non-participant' do
    stranger = create(:user)

    get "/api/v1/bookings/#{booking.id}", headers: auth_header_for(stranger)

    expect(response).to have_http_status(:not_found)
  end

  describe 'trip_planning_available' do
    let(:covered_listing) { create(:rv_listing, owner: owner, town: 'Lorne', state: 'VIC', postcode: '3232') }

    def seed_corpus
      KnowledgeChunk.create!(region: 'great-ocean-road', heading: 'Beaches', content: 'Sand.',
                             embedding: Array.new(768) { 0.1 }, model: 'nomic-embed-text', content_hash: 'x')
    end

    def available_for(target_booking)
      get "/api/v1/bookings/#{target_booking.id}", headers: auth_header_for(hirer)
      JSON.parse(response.body)['trip_planning_available']
    end

    it 'is true for a confirmed booking in a region that has a corpus' do
      seed_corpus
      confirmed = create(:booking, rv_listing: covered_listing, hirer: hirer, status: 'confirmed')

      expect(available_for(confirmed)).to be true
    end

    it 'is false when the booking is not confirmed' do
      seed_corpus
      pending = create(:booking, rv_listing: covered_listing, hirer: hirer, status: 'pending')

      expect(available_for(pending)).to be false
    end

    it 'is false when the region has no corpus' do
      uncovered = create(:rv_listing, owner: owner, town: 'Darwin', state: 'NT', postcode: '0800')
      confirmed = create(:booking, rv_listing: uncovered, hirer: hirer, status: 'confirmed')

      expect(available_for(confirmed)).to be false
    end
  end
end
