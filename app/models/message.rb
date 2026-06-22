class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :user

  validates :content, presence: true

  def as_json(options = {})
    super({ only: [:id, :content, :user_id, :chat_id, :read_at, :created_at] }.merge(options))
  end
end
