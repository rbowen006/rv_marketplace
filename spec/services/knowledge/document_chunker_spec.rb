require 'rails_helper'

RSpec.describe Knowledge::DocumentChunker do
  it 'splits markdown into one chunk per H2 section, keeping heading and body' do
    markdown = <<~MD
      <!-- a comment -->
      # Great Ocean Road
      Some intro under the title that belongs to no section.

      ## Beaches
      Sand and surf.
      More beach detail.

      ## Walks
      A nice walk.
    MD

    chunks = described_class.call(markdown)

    expect(chunks.map { |c| c[:heading] }).to eq(%w[Beaches Walks])

    beaches = chunks.first
    expect(beaches[:content]).to include('Sand and surf.')
    expect(beaches[:content]).to include('More beach detail.')
    expect(beaches[:content]).not_to include('##')
    expect(beaches[:content]).not_to include('intro under the title')
  end

  it 'drops sections with no body text' do
    markdown = "## Empty\n\n## Full\nHas content.\n"

    headings = described_class.call(markdown).map { |c| c[:heading] }

    expect(headings).to eq(['Full'])
  end
end
