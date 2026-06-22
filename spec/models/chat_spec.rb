require 'rails_helper'

RSpec.describe Chat, type: :model do
  it { should belong_to(:hirer).class_name('User') }
  it { should belong_to(:owner).class_name('User') }
  it { should belong_to(:rv_listing).optional }
  it { should belong_to(:booking).optional }
  it { should have_many(:messages).dependent(:destroy) }

  describe 'one unbooked chat per hirer-owner pair' do
    let(:hirer) { create(:user) }
    let(:owner) { create(:user) }
    let(:listing) { create(:rv_listing, owner: owner) }

    it 'allows a second chat between the same pair once the first is booked' do
      booking = create(:booking, hirer: hirer, rv_listing: listing)
      create(:chat, hirer: hirer, owner: owner, booking: booking)
      second_chat = build(:chat, hirer: hirer, owner: owner)
      expect(second_chat).to be_valid
    end

    it 'is invalid when an unbooked chat already exists for the same hirer-owner pair' do
      create(:chat, hirer: hirer, owner: owner)
      duplicate = build(:chat, hirer: hirer, owner: owner)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include('An active chat already exists with this owner')
    end
  end
end
