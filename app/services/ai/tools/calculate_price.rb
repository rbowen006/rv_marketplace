module Ai
  module Tools
    # Concierge tool (ADR-0014): total price for a listing over a date range.
    # Read-only; a bad input raises Ai::InputError so the agent gets an
    # is_error tool_result and recovers.
    class CalculatePrice
      include InputHelpers

      DEFINITION = {
        name: "calculate_price",
        description: "Calculate the total price to book a listing over a date range. " \
                     "Returns the number of nights, the nightly price, and the total.",
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

        nights = (end_date - start_date).to_i
        { nights: nights, price_per_day: listing.price_per_day, total: listing.price_per_day * nights }
      end
    end
  end
end
