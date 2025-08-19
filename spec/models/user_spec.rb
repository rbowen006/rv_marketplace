require 'rails_helper'

RSpec.describe User, type: :model do
  it { should have_many(:rv_listings) }
  it { should have_many(:bookings) }
  it { should have_many(:messages) }

  it 'validates presence of name and email' do
    user = User.new
    expect(user).not_to be_valid
  expect(user.errors[:email]).to include("can't be blank")
  expect(user.errors[:name]).to include("can't be blank")
  end

  it 'allows creating a user with valid attributes' do
    user = create(:user)
    expect(user).to be_persisted
    expect(user.email).to be_present
  end
end
