require 'rails_helper'

RSpec.describe Region::Resolver do
  describe '.call' do
    it 'resolves a town in a covered region to that region slug' do
      slug = described_class.call(town: 'Lorne', state: 'VIC', postcode: '3232')

      expect(slug).to eq('great-ocean-road')
    end

    it 'returns nil for a town outside every covered region' do
      slug = described_class.call(town: 'Gosford', state: 'NSW', postcode: '2250')

      expect(slug).to be_nil
    end
  end
end
