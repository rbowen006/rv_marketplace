require 'rails_helper'

RSpec.describe Booking, type: :model do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let(:listing) { create(:rv_listing, user: owner) }

  it 'rejects overlapping bookings' do
    create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 5, end_date: Date.today + 7, status: 'pending')
    booking = build(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 6, end_date: Date.today + 8)
    expect(booking).not_to be_valid
    expect(booking.errors[:base]).to include('Booking dates overlap with existing booking')
  end

  it 'allows non-overlapping bookings' do
    create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 5, end_date: Date.today + 7, status: 'pending')
    booking = build(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 8, end_date: Date.today + 10)
    expect(booking).to be_valid
  end

  it 'allows overlapping if existing booking is rejected' do
    create(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 5, end_date: Date.today + 7, status: 'rejected')
    booking = build(:booking, rv_listing: listing, user: hirer, start_date: Date.today + 6, end_date: Date.today + 8)
    expect(booking).to be_valid
  end
end
