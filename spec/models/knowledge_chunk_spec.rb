require 'rails_helper'

RSpec.describe KnowledgeChunk do
  it 'persists a chunk with its region, heading and 768-dimension embedding' do
    chunk = KnowledgeChunk.create!(
      region:       'great-ocean-road',
      heading:      'Beaches',
      content:      'Lorne main beach is calm and family-friendly.',
      embedding:    Array.new(768) { 0.1 },
      model:        'nomic-embed-text',
      content_hash: 'a'
    )

    expect(chunk.reload.embedding.to_a.length).to eq(768)
    expect(chunk.region).to eq('great-ocean-road')
    expect(chunk.heading).to eq('Beaches')
  end

  describe '.retrieve' do
    let(:near_vec)  { Array.new(768) { 0.10 } }
    let(:far_vec)   { Array.new(768) { 0.90 } }
    let(:query_vec) { Array.new(768) { 0.11 } }

    def chunk(region:, hash:, embedding:)
      KnowledgeChunk.create!(region: region, heading: hash, content: "content #{hash}",
                             embedding: embedding, model: 'nomic-embed-text', content_hash: hash)
    end

    it "returns only the region's chunks, nearest first, materialised as an array" do
      near  = chunk(region: 'great-ocean-road', hash: 'near', embedding: near_vec)
      far   = chunk(region: 'great-ocean-road', hash: 'far',  embedding: far_vec)
      other = chunk(region: 'byron-bay',        hash: 'other', embedding: near_vec)

      results = KnowledgeChunk.retrieve(region: 'great-ocean-road', query_embedding: query_vec, limit: 5)

      expect(results).to be_an(Array)
      expect(results.map(&:region).uniq).to eq([ 'great-ocean-road' ])
      expect(results.first).to eq(near)
      expect(results).to include(far)
      expect(results).not_to include(other)
    end
  end
end
