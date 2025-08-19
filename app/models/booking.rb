class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :rv_listing

  STATUSES = %w[pending confirmed rejected].freeze

  validates :start_date, :end_date, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_after_start
  validate :no_date_overlap

  private

  def end_after_start
    return if end_date.blank? || start_date.blank?
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end

  def no_date_overlap
    return if start_date.blank? || end_date.blank? || rv_listing.nil?

    overlapping = rv_listing.bookings.where.not(id: id).where.not(status: 'rejected')
                      .where('(start_date <= ?) AND (end_date >= ?)', end_date, start_date)
    if overlapping.exists?
      errors.add(:base, 'Booking dates overlap with existing booking')
    end
  end
  public

  def as_json(options = {})
    super({ only: [:id, :start_date, :end_date, :status, :user_id, :rv_listing_id] }.merge(options))
  end
end
