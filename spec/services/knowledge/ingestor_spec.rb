require 'rails_helper'

RSpec.describe Knowledge::Ingestor do
  let(:embedding) { Array.new(768) { 0.02 } }
  let(:markdown)  { "## Beaches\nSand.\n\n## Walks\nA walk.\n" }

  before do
    stub_request(:post, "http://ollama:11434/api/embeddings")
      .to_return(status: 200, body: { embedding: embedding }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  it 'creates one embedded KnowledgeChunk per H2 section' do
    expect {
      described_class.call(region: 'test-region', markdown: markdown)
    }.to change { KnowledgeChunk.where(region: 'test-region').count }.from(0).to(2)

    beaches = KnowledgeChunk.find_by(region: 'test-region', heading: 'Beaches')
    expect(beaches.content).to eq('Sand.')
    expect(beaches.embedding.to_a.length).to eq(768)
    expect(beaches.model).to eq('nomic-embed-text')
  end

  it 're-embeds nothing when the corpus is unchanged (idempotent)' do
    described_class.call(region: 'test-region', markdown: markdown)

    expect(Ai::Embedder).not_to receive(:call)
    expect {
      described_class.call(region: 'test-region', markdown: markdown)
    }.not_to change { KnowledgeChunk.where(region: 'test-region').count }
  end

  it 'prunes chunks whose section was changed or removed' do
    described_class.call(region: 'test-region', markdown: markdown)

    revised = "## Beaches\nSand and surf now.\n" # Walks removed, Beaches reworded
    described_class.call(region: 'test-region', markdown: revised)

    chunks = KnowledgeChunk.where(region: 'test-region')
    expect(chunks.pluck(:heading)).to eq([ 'Beaches' ])
    expect(chunks.first.content).to eq('Sand and surf now.')
  end
end
