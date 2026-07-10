require 'rails_helper'

RSpec.describe RvListing, type: :model do
  it { should belong_to(:owner) }
  it { should have_many(:bookings) }
  it { should have_many(:chats) }

  it { should validate_presence_of(:title) }
  it { should validate_presence_of(:description) }
  it { should validate_presence_of(:town) }
  it { should validate_presence_of(:state) }
  it { should validate_presence_of(:postcode) }
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

  describe 'embedding refresh' do
    it 'enqueues a GenerateListingEmbeddingJob after create' do
      allow(GenerateListingEmbeddingJob).to receive(:perform_later)
      listing = create(:rv_listing)
      expect(GenerateListingEmbeddingJob).to have_received(:perform_later).with(listing.id)
    end

    it 'enqueues a GenerateListingEmbeddingJob after update' do
      listing = create(:rv_listing)
      allow(GenerateListingEmbeddingJob).to receive(:perform_later)
      listing.update!(title: 'A refreshed headline')
      expect(GenerateListingEmbeddingJob).to have_received(:perform_later).with(listing.id)
    end
  end

  describe '#embedding_document' do
    it 'renders the structured fields as prose and appends the free text, excluding price' do
      listing = build(
        :rv_listing,
        rv_type:       :caravan,
        town:          'Byron Bay',
        state:         'NSW',
        max_guests:    4,
        pet_friendly:  true,
        price_per_day: 950,
        title:         'Cosy coastal caravan',
        description:   'A lovely home on wheels near the beach.'
      )

      expect(listing.embedding_document).to eq(
        'Caravan in Byron Bay, NSW. Sleeps 4 guests. Pet-friendly. ' \
        'Cosy coastal caravan. A lovely home on wheels near the beach.'
      )
      expect(listing.embedding_document).not_to include('950')
    end

    it 'omits the pet-friendly clause when the listing does not allow pets' do
      listing = build(:rv_listing, rv_type: :motorhome, town: 'Cairns', state: 'QLD',
                                    max_guests: 2, pet_friendly: false,
                                    title: 'Compact motorhome', description: 'Great for couples.')

      expect(listing.embedding_document).to eq(
        'Motorhome in Cairns, QLD. Sleeps 2 guests. Compact motorhome. Great for couples.'
      )
    end
  end

  describe 'region assignment' do
    it 'assigns the resolved region slug on save' do
      listing = build(:rv_listing, town: 'Lorne', state: 'VIC', postcode: '3232')
      listing.valid?
      expect(listing.region).to eq('great-ocean-road')
    end

    it 'leaves region nil for a town outside every covered region' do
      listing = build(:rv_listing, town: 'Gosford', state: 'NSW', postcode: '2250')
      listing.valid?
      expect(listing.region).to be_nil
    end
  end
end
