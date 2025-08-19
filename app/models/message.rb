class Message < ApplicationRecord
  belongs_to :user
  belongs_to :rv_listing

  validates :content, presence: true

  def as_json(options = {})
    super({ only: [:id, :content, :user_id, :rv_listing_id, :created_at] }.merge(options))
  end
end
