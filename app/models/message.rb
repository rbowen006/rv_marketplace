class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :user

  validates :content, presence: true

  after_create_commit :update_chat_inbox_fields

  def as_json(options = {})
    super({ only: [:id, :content, :user_id, :chat_id, :read_at, :created_at] }.merge(options))
  end

  private

  def update_chat_inbox_fields
    Chat.where(id: chat_id)
        .where('last_message_at IS NULL OR last_message_at < ?', created_at)
        .update_all(last_message_at: created_at, last_message_content: content)
  end
end
