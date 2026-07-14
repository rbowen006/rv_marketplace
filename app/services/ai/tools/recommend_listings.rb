module Ai
  module Tools
    # Concierge tool (ADR-0014): the structured UI-output channel. The agent
    # calls this with the listing ids it wants to surface as cards; the ids live
    # in the tool_use block on the transcript (the record the poll endpoint
    # derives recommendations from) and the tool returns an ack. Validates that
    # every id is a real listing so a hallucinated id never renders a card. This
    # is the SDK's "send_to_user" pattern — a tool whose input drives the UI.
    class RecommendListings
      DEFINITION = {
        name: "recommend_listings",
        description: "Surface specific listings to the traveller as recommendation cards. Pass the ids " \
                     "of listings you found via search_listings and want to show. Only real ids are allowed.",
        input_schema: {
          "type" => "object",
          "required" => %w[listing_ids],
          "properties" => {
            "listing_ids" => {
              "type" => "array",
              "items" => { "type" => "integer" },
              "description" => "Ids of listings to recommend, in the order to display them."
            }
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
        ids = Array(@input["listing_ids"]).map(&:to_i).uniq
        missing = ids - RvListing.where(id: ids).pluck(:id)
        raise Ai::InputError, "Unknown listing ids: #{missing.join(', ')}" if missing.any?

        { recommended: ids }
      end
    end
  end
end
