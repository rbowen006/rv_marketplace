require 'rails_helper'
require 'rake'

RSpec.describe 'embeddings:backfill', type: :task do
  before do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/embeddings', [ Rails.root.join('lib').to_s ])
    Rake::Task.define_task(:environment)
  end

  it 'enqueues an embedding job for every listing' do
    listings = create_list(:rv_listing, 2)
    allow(GenerateListingEmbeddingJob).to receive(:perform_later)

    Rake::Task['embeddings:backfill'].invoke

    listings.each do |listing|
      expect(GenerateListingEmbeddingJob).to have_received(:perform_later).with(listing.id)
    end
  end
end
