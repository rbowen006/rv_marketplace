require 'rails_helper'
require 'rake'

RSpec.describe 'knowledge:embed', type: :task do
  before do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/knowledge', [Rails.root.join('lib').to_s])
    Rake::Task.define_task(:environment)
  end

  it 'ingests every region that has a corpus document' do
    regions_with_docs = Region.all.select { |region| region.doc_body.present? }
    expect(regions_with_docs).not_to be_empty

    regions_with_docs.each do |region|
      expect(Knowledge::Ingestor).to receive(:call)
        .with(region: region.slug, markdown: kind_of(String)).and_return(0)
    end

    Rake::Task['knowledge:embed'].invoke
  end
end
