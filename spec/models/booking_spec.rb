require 'rails_helper'

RSpec.describe Booking, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:rv_listing) }

  it { should validate_presence_of(:start_date) }
  it { should validate_presence_of(:end_date) }
  it 'requires status and validates inclusion' do
    b = build(:booking, status: nil)
    expect(b).not_to be_valid
    expect(b.errors[:status]).to include("can't be blank")
    b2 = build(:booking, status: 'weird')
    expect(b2).not_to be_valid
    expect(b2.errors[:status]).to be_present
  end

  it 'validates end date after start date' do
    booking = build(:booking, start_date: Date.today + 5, end_date: Date.today + 5)
    expect(booking).not_to be_valid
    expect(booking.errors[:end_date]).to include('must be after start date')
  end

  it 'rejects start date in the past' do
    booking = build(:booking, start_date: Date.today - 1, end_date: Date.today + 2)
    expect(booking).not_to be_valid
    expect(booking.errors[:start_date]).to include('cannot be in the past')
  end

  it 'rejects overlapping pending/confirmed bookings' do
    existing = create(:booking, start_date: Date.today + 10, end_date: Date.today + 12, status: 'pending')
    overlap = build(:booking, rv_listing: existing.rv_listing, start_date: Date.today + 11, end_date: Date.today + 13)
    expect(overlap).not_to be_valid
    expect(overlap.errors[:base]).to include('Booking dates overlap with existing booking')
  end

  it 'allows non-overlapping booking' do
    existing = create(:booking, start_date: Date.today + 10, end_date: Date.today + 12, status: 'pending')
    separate = build(:booking, rv_listing: existing.rv_listing, start_date: Date.today + 13, end_date: Date.today + 14)
    expect(separate).to be_valid
  end
end
