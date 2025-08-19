require 'rails_helper'

RSpec.describe RvListing, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:bookings) }
  it { should have_many(:messages) }

  it { should validate_presence_of(:title) }
  it { should validate_presence_of(:description) }
  it { should validate_presence_of(:location) }
  it { should validate_presence_of(:price_per_day) }
end
