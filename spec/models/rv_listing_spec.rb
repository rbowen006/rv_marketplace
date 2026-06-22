require 'rails_helper'

RSpec.describe RvListing, type: :model do
  it { should belong_to(:owner) }
  it { should have_many(:bookings) }
  it { should have_many(:chats) }

  it { should validate_presence_of(:title) }
  it { should validate_presence_of(:description) }
  it { should validate_presence_of(:location) }
  it { should validate_presence_of(:price_per_day) }
  it { should validate_presence_of(:max_guests) }

  it 'defaults pet_friendly to false' do
    listing = build(:rv_listing)
    expect(listing.pet_friendly).to eq(false)
  end

  it 'accepts optional latitude and longitude' do
    listing = build(:rv_listing, latitude: -33.8688, longitude: 151.2093)
    expect(listing).to be_valid
  end
end
