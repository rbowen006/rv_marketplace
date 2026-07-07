require 'rails_helper'
require 'rake'

RSpec.describe 'knowledge:embed', type: :task do
  before do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/knowledge', [Rails.root.join('lib').to_s])
    Rake::Task.define_task(:environment)
  end

  it 'ingests every region that has a corpus document' do
    expect(Knowledge::Ingestor).to receive(:call).with(region: 'great-ocean-road', markdown: kind_of(String))
    expect(Knowledge::Ingestor).to receive(:call).with(region: 'byron-bay', markdown: kind_of(String))

    Rake::Task['knowledge:embed'].invoke
  end
end
