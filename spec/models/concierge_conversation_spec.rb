require 'rails_helper'

RSpec.describe ConciergeConversation do
  let(:user) { create(:user) }

  it 'belongs to a user and defaults to idle' do
    conversation = ConciergeConversation.create!(user: user)

    expect(conversation.user).to eq(user)
    expect(conversation).to be_idle
  end

  it 'cycles through the per-turn statuses' do
    conversation = ConciergeConversation.create!(user: user)

    conversation.processing!
    expect(conversation).to be_processing

    conversation.idle!
    expect(conversation).to be_idle

    conversation.failed!
    expect(conversation).to be_failed
  end

  it 'allows only one active conversation per user' do
    ConciergeConversation.create!(user: user)

    expect { ConciergeConversation.create!(user: user) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'nullifies its ai_requests on destroy so the audit log survives (issue #53)' do
    conversation = ConciergeConversation.create!(user: user)
    request = AiRequest.create!(feature: 'concierge', model: 'claude-sonnet-5', user: user, conversation_id: conversation.id)

    expect { conversation.destroy! }.not_to raise_error

    expect(AiRequest.exists?(request.id)).to be(true)
    expect(request.reload.conversation_id).to be_nil
  end
end
