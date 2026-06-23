require 'rails_helper'

RSpec.describe Message, type: :model do
  it { should belong_to(:chat) }
  it { should belong_to(:user) }
  it { should validate_presence_of(:content) }

  describe 'chat denormalization' do
    let(:chat) { create(:chat) }

    it 'updates last_message_at and last_message_content on the chat after create' do
      message = create(:message, chat: chat, content: 'Hello there')
      chat.reload
      expect(chat.last_message_at).to be_within(1.second).of(message.created_at)
      expect(chat.last_message_content).to eq('Hello there')
    end

    it 'does not overwrite a more recent last_message_at with an older timestamp' do
      later_time = 1.hour.from_now
      chat.update_columns(last_message_at: later_time)
      create(:message, chat: chat, content: 'Stale message')
      chat.reload
      expect(chat.last_message_at).to be_within(1.second).of(later_time)
    end
  end
end
