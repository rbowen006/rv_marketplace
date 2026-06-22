class Chat < ApplicationRecord
  belongs_to :hirer, class_name: 'User'
  belongs_to :owner, class_name: 'User'
  belongs_to :rv_listing, optional: true
  belongs_to :booking, optional: true

  has_many :messages, dependent: :destroy

  validate :one_unbooked_chat_per_hirer_owner_pair

  def self.find_or_initialize_unbooked(hirer, owner)
    find_by(hirer_id: hirer.id, owner_id: owner.id, booking_id: nil) ||
      new(hirer: hirer, owner: owner)
  end

  def as_json(include_messages: false, **options)
    base = super({ only: [:id, :hirer_id, :owner_id, :rv_listing_id, :booking_id] }.merge(options))
    base['messages'] = messages.order(:created_at).as_json if include_messages
    base
  end

  private

  def one_unbooked_chat_per_hirer_owner_pair
    return if booking_id.present?
    exists = Chat.where(hirer_id: hirer_id, owner_id: owner_id, booking_id: nil)
                 .where.not(id: id)
                 .exists?
    errors.add(:base, 'An active chat already exists with this owner') if exists
  end
end
