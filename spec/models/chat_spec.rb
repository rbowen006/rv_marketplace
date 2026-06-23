require 'rails_helper'

RSpec.describe Chat, type: :model do
  it { should belong_to(:hirer).class_name('User') }
  it { should belong_to(:owner).class_name('User') }
  it { should belong_to(:rv_listing).optional }
  it { should belong_to(:booking).optional }
  it { should have_many(:messages).dependent(:destroy) }

  describe '.resync_inbox_fields!' do
    it 'leaves a chat with no messages untouched' do
      chat = create(:chat)
      chat.update_columns(last_message_at: nil, last_message_content: nil)

      Chat.resync_inbox_fields!

      chat.reload
      expect(chat.last_message_at).to be_nil
      expect(chat.last_message_content).to be_nil
    end

    it 'is idempotent — a chat already in sync is unaffected by a second run' do
      chat = create(:chat)
      message = create(:message, chat: chat, content: 'Correct content')
      chat.reload

      Chat.resync_inbox_fields!
      chat.reload

      expect(chat.last_message_at).to be_within(1.second).of(message.created_at)
      expect(chat.last_message_content).to eq('Correct content')
    end

    it 'corrects multiple chats in one call' do
      chat_a = create(:chat)
      chat_b = create(:chat)
      msg_a = create(:message, chat: chat_a, content: 'Message A')
      msg_b = create(:message, chat: chat_b, content: 'Message B')
      chat_a.update_columns(last_message_at: 1.hour.ago, last_message_content: 'Stale A')
      chat_b.update_columns(last_message_at: 1.hour.ago, last_message_content: 'Stale B')

      Chat.resync_inbox_fields!

      expect(chat_a.reload.last_message_content).to eq('Message A')
      expect(chat_b.reload.last_message_content).to eq('Message B')
    end

    it 'corrects stale last_message_at and last_message_content from actual messages' do
      chat = create(:chat)
      message = create(:message, chat: chat, content: 'Latest message')
      chat.update_columns(last_message_at: 1.hour.ago, last_message_content: 'Stale content')

      Chat.resync_inbox_fields!

      chat.reload
      expect(chat.last_message_at).to be_within(1.second).of(message.created_at)
      expect(chat.last_message_content).to eq('Latest message')
    end
  end

  describe 'one unbooked chat per hirer-owner pair' do
    let(:hirer) { create(:user) }
    let(:owner) { create(:user) }
    let(:listing) { create(:rv_listing, owner: owner) }

    it 'allows a second chat between the same pair once the first is booked' do
      booking = create(:booking, hirer: hirer, rv_listing: listing)
      create(:chat, hirer: hirer, owner: owner, booking: booking)
      second_chat = build(:chat, hirer: hirer, owner: owner)
      expect(second_chat).to be_valid
    end

    it 'is invalid when an unbooked chat already exists for the same hirer-owner pair' do
      create(:chat, hirer: hirer, owner: owner)
      duplicate = build(:chat, hirer: hirer, owner: owner)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include('An active chat already exists with this owner')
    end
  end
end
