class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :rv_listing

  STATUSES = %w[pending confirmed rejected cancelled].freeze

  validates :start_date, :end_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :end_after_start
  validate :start_not_in_past
  validate :no_date_overlap

  private

  def end_after_start
    return if end_date.blank? || start_date.blank?
    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def start_not_in_past
    return if start_date.blank?
    errors.add(:start_date, 'cannot be in the past') if start_date < Date.current
  end

  def no_date_overlap
    return if start_date.blank? || end_date.blank? || rv_listing.nil?
    overlapping = rv_listing.bookings.where.not(id: id)
                                   .where(status: %w[pending confirmed])
                                   .where('NOT (end_date < :s OR start_date > :e)', s: start_date, e: end_date)
    errors.add(:base, 'Booking dates overlap with existing booking') if overlapping.exists?
  end
  public

  def as_json(options = {})
    super({ only: [:id, :start_date, :end_date, :status, :user_id, :rv_listing_id] }.merge(options))
  end
end
