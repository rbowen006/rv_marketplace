require 'rails_helper'

RSpec.describe TripPlan do
  let(:booking) { create(:booking) }

  it 'belongs to a booking and defaults to pending' do
    plan = TripPlan.create!(booking: booking)

    expect(plan.booking).to eq(booking)
    expect(plan).to be_pending
  end

  it 'allows only one plan per booking' do
    TripPlan.create!(booking: booking)

    expect { TripPlan.create!(booking: booking) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'moves through the generation lifecycle statuses' do
    plan = TripPlan.create!(booking: booking)

    plan.processing!
    expect(plan).to be_processing

    plan.completed!
    expect(plan).to be_completed
  end
end
