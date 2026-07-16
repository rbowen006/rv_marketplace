class Chat < ApplicationRecord
  belongs_to :hirer, class_name: "User"
  belongs_to :owner, class_name: "User"
  belongs_to :rv_listing, optional: true
  belongs_to :booking, optional: true

  has_many :messages, dependent: :destroy

  validate :one_unbooked_chat_per_hirer_owner_pair

  def self.resync_inbox_fields!
    latest = Message.from(
      Message.select("DISTINCT ON (chat_id) chat_id, content, created_at AS max_at")
             .order("chat_id, created_at DESC"),
      :messages
    )
    latest.each do |row|
      where(id: row.chat_id).update_all(
        last_message_at: row.max_at,
        last_message_content: row.content
      )
    end
  end

  def self.find_or_initialize_unbooked(hirer, owner)
    find_by(hirer_id: hirer.id, owner_id: owner.id, booking_id: nil) ||
      new(hirer: hirer, owner: owner)
  end

  def as_json(include_messages: false, include_participants: false, **options)
    base = super({
      only: [ :id, :hirer_id, :owner_id, :rv_listing_id, :booking_id,
             :last_message_at, :last_message_content, :hirer_last_read_at, :owner_last_read_at ]
    }.merge(options))
    base["messages"] = messages.order(:created_at).as_json if include_messages
    if include_participants
      base["hirer"] = { id: hirer.id, name: hirer.name }
      base["owner"] = { id: owner.id, name: owner.name }
      base["listing_title"] = rv_listing&.title
    end
    base
  end

  private

  def one_unbooked_chat_per_hirer_owner_pair
    return if booking_id.present?
    exists = Chat.where(hirer_id: hirer_id, owner_id: owner_id, booking_id: nil)
                 .where.not(id: id)
                 .exists?
    errors.add(:base, "An active chat already exists with this owner") if exists
  end
end
