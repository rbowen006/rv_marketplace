class GenerateTripPlanJob < ApplicationJob
  queue_as :default

  # No Sidekiq retries at all (ADR-0013): even an unexpected error must not
  # trigger the default 25-retry backoff, each attempt being a paid Claude call.
  sidekiq_options retry: 0

  # Generates a trip plan's itinerary via RAG (ADR-0013). No automatic retries:
  # a failed generation is a paid Claude call, so we record the failure and let
  # the hirer retry manually rather than let Sidekiq thrash the API. Catching
  # Ai::Error here means the job completes, so it is never re-run.
  def perform(trip_plan_id)
    plan = TripPlan.find_by(id: trip_plan_id)
    return unless plan

    plan.processing!
    itinerary = Ai::TripPlanner.call(
      booking:   plan.booking,
      interests: plan.interests,
      user:      plan.booking.hirer
    )
    plan.update!(status: :completed, itinerary: itinerary, error: nil)
  rescue Ai::Error => e
    plan&.update!(status: :failed, error: e.message)
  end
end
