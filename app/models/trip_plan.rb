# A hirer's generated trip plan for a confirmed booking (ADR-0013). Exactly one
# per booking (unique index), regenerated in place. The status drives the
# frontend poller: pending -> processing -> completed | failed.
class TripPlan < ApplicationRecord
  belongs_to :booking

  enum :status, { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' },
       default: :pending
end
