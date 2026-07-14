module Ai
  module Tools
    # Concierge tool (ADR-0014): full public detail for one listing. Reuses
    # RvListing#as_json, which already exposes only public fields (no embeddings
    # or internal columns) — data minimisation for free. Read-only; a bad input
    # raises Ai::InputError.
    class GetListingDetail
      include InputHelpers

      DEFINITION = {
        name: "get_listing_detail",
        description: "Get the full public detail for one listing by id, including price, " \
                     "location, capacity, description, and owner.",
        input_schema: {
          "type" => "object",
          "required" => %w[listing_id],
          "properties" => {
            "listing_id" => { "type" => "integer", "description" => "The RV listing id." }
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
        resolve_listing!(@input["listing_id"]).as_json
      end
    end
  end
end
