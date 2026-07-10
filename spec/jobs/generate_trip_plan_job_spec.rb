require 'rails_helper'

RSpec.describe GenerateTripPlanJob do
  let(:owner)   { create(:user) }
  let(:hirer)   { create(:user) }
  let(:listing) { create(:rv_listing, owner: owner, town: 'Lorne', state: 'VIC', postcode: '3232') }
  let(:booking) { create(:booking, rv_listing: listing, hirer: hirer, status: 'confirmed') }
  let(:plan)    { TripPlan.create!(booking: booking, interests: 'quiet beaches', status: 'pending') }

  let(:itinerary) { { "summary" => "Two days", "disclaimer" => "Verify locally.", "days" => [] } }

  it 'generates the itinerary and marks the plan completed' do
    allow(Ai::TripPlanner).to receive(:call)
      .with(booking: booking, interests: 'quiet beaches', user: hirer)
      .and_return(itinerary)

    described_class.perform_now(plan.id)

    plan.reload
    expect(plan).to be_completed
    expect(plan.itinerary).to eq(itinerary)
    expect(plan.error).to be_nil
  end

  it 'marks the plan failed and does not raise when generation errors' do
    allow(Ai::TripPlanner).to receive(:call).and_raise(Ai::ApiError.new("Claude is unavailable"))

    expect { described_class.perform_now(plan.id) }.not_to raise_error

    plan.reload
    expect(plan).to be_failed
    expect(plan.error).to eq("Claude is unavailable")
  end
end
