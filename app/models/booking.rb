class Booking < ApplicationRecord
  belongs_to :hirer, class_name: 'User'
  belongs_to :rv_listing

  STATUSES = %w[pending confirmed rejected cancelled].freeze

  validates :start_date, :end_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :end_after_start
  validate :start_not_in_past
  validate :no_date_overlap

  # Bookings that hold a date range: pending or confirmed (rejected/cancelled
  # free the dates). Shared by the overlap validation and the concierge's
  # check_availability tool (ADR-0014) so both agree on what "taken" means.
  scope :active, -> { where(status: %w[pending confirmed]) }
  scope :overlapping, ->(start_date, end_date) {
    active.where('NOT (end_date < :s OR start_date > :e)', s: start_date, e: end_date)
  }

  # Trip planning is offered only for a confirmed booking whose region has an
  # embedded corpus to ground on (ADR-0013) — so every itinerary is grounded.
  def trip_planning_available?
    return false unless status == 'confirmed'

    slug = rv_listing.region
    return false if slug.blank?

    Region.find(slug)&.has_corpus? || false
  end

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
    clashing = rv_listing.bookings.where.not(id: id).overlapping(start_date, end_date)
    errors.add(:base, 'Booking dates overlap with existing booking') if clashing.exists?
  end
  public

  def as_json(include_participants: false, **options)
    base = super({ only: [:id, :start_date, :end_date, :status, :hirer_id, :rv_listing_id] }.merge(options))
    if include_participants
      base['hirer'] = { id: hirer.id, name: hirer.name }
      base['owner'] = { id: rv_listing.owner.id, name: rv_listing.owner.name }
      base['listing_title'] = rv_listing.title
    end
    base
  end
end
