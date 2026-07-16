module Ai
  module Tools
    # Concierge tool (ADR-0014): is a listing free over a date range? Reuses
    # Booking.overlapping so it agrees with the booking-overlap validation on
    # what "taken" means. Read-only; a bad input raises Ai::InputError.
    class CheckAvailability
      include InputHelpers

      DEFINITION = {
        name: "check_availability",
        description: "Check whether a listing is available (unbooked) over a date range. " \
                     "Returns { available: true|false }.",
        input_schema: {
          "type" => "object",
          "required" => %w[listing_id start_date end_date],
          "properties" => {
            "listing_id" => { "type" => "integer", "description" => "The RV listing id." },
            "start_date" => { "type" => "string", "description" => "Check-in date (YYYY-MM-DD)." },
            "end_date"   => { "type" => "string", "description" => "Check-out date (YYYY-MM-DD)." }
          }
        }
      }.freeze

      def self.call(input)
        new(input).call
      end

      def initialize(input)
        @input = input
      end

      def call
        listing = resolve_listing!(@input["listing_id"])
        start_date, end_date = parse_range!(@input["start_date"], @input["end_date"])

        { available: listing.bookings.overlapping(start_date, end_date).none? }
      end
    end
  end
end
