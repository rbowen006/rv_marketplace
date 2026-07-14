module Ai
  module Tools
    # Concierge tool (ADR-0014): semantic search over listings with optional
    # filters, returning pruned summaries. Reuses the NL-search path (Ai::Embedder
    # + ListingEmbedding.nearest_neighbors). Returns pruned summaries (not full
    # records) so every re-sent tool result stays within the token budget and the
    # prompt-injection surface stays small. Read-only; a blank query raises
    # Ai::InputError.
    class SearchListings
      SEARCH_LIMIT = 10

      DEFINITION = {
        name: "search_listings",
        description: "Semantic search over RV listings by a natural-language description of what the " \
                     "traveller wants, with optional filters. Returns pruned listing summaries.",
        input_schema: {
          "type" => "object",
          "required" => %w[query],
          "properties" => {
            "query"        => { "type" => "string", "description" => "Natural-language description of the desired RV/trip." },
            "state"        => { "type" => "string", "description" => "Optional: restrict to an Australian state, e.g. NSW." },
            "min_guests"   => { "type" => "integer", "description" => "Optional: minimum guest capacity." },
            "pet_friendly" => { "type" => "boolean", "description" => "Optional: only pet-friendly listings." }
          }
        }
      }.freeze

      def self.call(input, user: nil)
        new(input, user: user).call
      end

      def initialize(input, user: nil)
        @input = input
        @user = user
      end

      def call
        query = @input["query"].to_s.strip
        raise Ai::InputError, "query is required" if query.blank?

        vector = Ai::Embedder.call(query, feature: "concierge_search", user: @user)

        embeddings = filtered(
          ListingEmbedding.nearest_neighbors(:embedding, vector, distance: :cosine).joins(:rv_listing)
        ).limit(SEARCH_LIMIT).to_a

        # Materialised (.to_a) before any ordering-sensitive access — never call
        # .last on a live nearest_neighbors relation (pgvector ORDER BY reversal).
        listings = RvListing.where(id: embeddings.map(&:rv_listing_id)).index_by(&:id)
        embeddings.map { |embedding| prune(listings.fetch(embedding.rv_listing_id)) }
      end

      private

      def filtered(scope)
        scope = scope.where(rv_listings: { state: @input["state"] }) if @input["state"].present?
        scope = scope.where("rv_listings.max_guests >= ?", @input["min_guests"]) if @input["min_guests"].present?
        scope = scope.where(rv_listings: { pet_friendly: true }) if @input["pet_friendly"]
        scope
      end

      def prune(listing)
        {
          id:            listing.id,
          title:         listing.title,
          town:          listing.town,
          state:         listing.state,
          price_per_day: listing.price_per_day,
          max_guests:    listing.max_guests,
          pet_friendly:  listing.pet_friendly,
          blurb:         listing.description.to_s.truncate(200)
        }
      end
    end
  end
end
