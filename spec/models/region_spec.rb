require 'rails_helper'

RSpec.describe Region do
  describe '.find' do
    it 'returns the region matching a slug' do
      region = Region.find('great-ocean-road')

      expect(region.name).to eq('Great Ocean Road')
      expect(region.state).to eq('VIC')
    end

    it 'returns nil for an unknown slug' do
      expect(Region.find('atlantis')).to be_nil
    end
  end

  describe '.all (manifest invariants)' do
    it 'maps each town to exactly one region in the real manifest' do
      towns = Region.all.flat_map(&:towns)

      expect(towns).to eq(towns.uniq)
    end

    it 'raises a ManifestError when a town is mapped to two regions' do
      allow(Region).to receive(:manifest).and_return([
        { 'slug' => 'a', 'name' => 'A', 'state' => 'NSW', 'towns' => ['Gosford'] },
        { 'slug' => 'b', 'name' => 'B', 'state' => 'NSW', 'towns' => ['Gosford'] }
      ])

      expect { Region.all }.to raise_error(Region::ManifestError, /Gosford/)
    end
  end

  describe '#has_corpus?' do
    it 'is false until the region has embedded chunks, then true' do
      region = Region.find('great-ocean-road')
      expect(region.has_corpus?).to be false

      KnowledgeChunk.create!(region: 'great-ocean-road', heading: 'Beaches', content: 'Sand.',
                             embedding: Array.new(768) { 0.1 }, model: 'nomic-embed-text', content_hash: 'x')

      expect(region.has_corpus?).to be true
    end
  end
end
