require 'rails_helper'

RSpec.describe Booking, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:rv_listing) }

  it { should validate_presence_of(:start_date) }
  it { should validate_presence_of(:end_date) }
  it { should validate_presence_of(:status) }

  it 'validates end date after start date' do
    booking = build(:booking, start_date: Date.today + 5, end_date: Date.today + 3)
    expect(booking).not_to be_valid
    expect(booking.errors[:end_date]).to include('must be after start date')
  end
end
