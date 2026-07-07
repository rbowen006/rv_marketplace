require 'rails_helper'

RSpec.describe 'Trip plans', type: :request do
  let(:owner)   { create(:user) }
  let(:hirer)   { create(:user) }
  let(:listing) { create(:rv_listing, owner: owner, town: 'Lorne', state: 'VIC', postcode: '3232') }
  let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, status: 'confirmed') }

  before do
    KnowledgeChunk.create!(region: 'great-ocean-road', heading: 'Beaches', content: 'Sand.',
                           embedding: Array.new(768) { 0.1 }, model: 'nomic-embed-text', content_hash: 'x')
    allow(GenerateTripPlanJob).to receive(:perform_later)
  end

  def post_plan(user: hirer, interests: 'quiet beaches')
    post "/api/v1/bookings/#{booking.id}/trip_plan",
         params: { interests: interests }.to_json, headers: auth_header_for(user)
  end

  it 'creates a pending plan and enqueues generation for the hirer' do
    post_plan

    expect(response).to have_http_status(:accepted)
    expect(GenerateTripPlanJob).to have_received(:perform_later)

    body = JSON.parse(response.body)
    expect(body['status']).to eq('success')
    expect(body['data']['status']).to eq('pending')

    plan = TripPlan.find_by(booking_id: booking.id)
    expect(plan.interests).to eq('quiet beaches')
  end

  it 'forbids a non-hirer from generating a plan' do
    post_plan(user: owner)

    expect(response).to have_http_status(:forbidden)
    expect(GenerateTripPlanJob).not_to have_received(:perform_later)
  end

  it 'returns 422 when trip planning is not available for the booking' do
    uncovered_listing = create(:rv_listing, owner: owner, town: 'Darwin', state: 'NT', postcode: '0800')
    uncovered_booking = create(:booking, rv_listing: uncovered_listing, hirer: hirer, status: 'confirmed')

    post "/api/v1/bookings/#{uncovered_booking.id}/trip_plan",
         params: { interests: 'x' }.to_json, headers: auth_header_for(hirer)

    expect(response).to have_http_status(:unprocessable_content)
    expect(GenerateTripPlanJob).not_to have_received(:perform_later)
  end

  it 'returns 409 when a plan is already generating' do
    TripPlan.create!(booking: booking, status: 'processing')

    post_plan

    expect(response).to have_http_status(:conflict)
    expect(GenerateTripPlanJob).not_to have_received(:perform_later)
  end

  it 'reuses a completed plan without re-generating when interests are unchanged' do
    post_plan(interests: 'quiet beaches')
    plan = TripPlan.find_by(booking_id: booking.id)
    plan.update!(status: 'completed', itinerary: { 'summary' => 's', 'disclaimer' => 'd', 'days' => [] })

    expect(GenerateTripPlanJob).not_to receive(:perform_later)
    post_plan(interests: 'quiet beaches')

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['data']['status']).to eq('completed')
  end

  it 'rate limits generation per user' do
    5.times { post_plan }
    post_plan

    expect(response).to have_http_status(:too_many_requests)
  end

  describe 'GET show' do
    it 'returns a none status when no plan exists yet' do
      get "/api/v1/bookings/#{booking.id}/trip_plan", headers: auth_header_for(hirer)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['status']).to eq('none')
    end

    it 'returns the completed itinerary' do
      TripPlan.create!(booking: booking, status: 'completed',
                       itinerary: { 'summary' => 'Coastal days', 'disclaimer' => 'd', 'days' => [] })

      get "/api/v1/bookings/#{booking.id}/trip_plan", headers: auth_header_for(hirer)

      data = JSON.parse(response.body)['data']
      expect(data['status']).to eq('completed')
      expect(data['itinerary']['summary']).to eq('Coastal days')
    end

    it 'forbids a non-hirer' do
      get "/api/v1/bookings/#{booking.id}/trip_plan", headers: auth_header_for(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
