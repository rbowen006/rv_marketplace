module Api
  module V1
    class ListingsController < BaseController
      skip_before_action :authenticate_user!, only: [ :index, :show, :search ]
      before_action :set_listing, only: [ :show, :update, :destroy ]
      before_action :authorize_owner!, only: [ :update, :destroy ]

      # Number of nearest neighbours returned by natural-language search.
      # No relevance threshold in v1 — kNN always returns up to this many rows,
      # so even a nonsense query yields listings (ADR-0011).
      SEARCH_LIMIT = 20

      def index
        @listings = RvListing.all
        render json: @listings
      end

      # POST /api/v1/listings/search — natural-language semantic search.
      # Embeds the query, finds the nearest listing embeddings by cosine
      # distance, and renders the full listings in ranked order with a score.
      def search
        query = params[:query].to_s.strip
        if query.blank?
          render json: { error: "query is required" }, status: :unprocessable_content
          return
        end

        vector = Ai::Embedder.call(query, feature: "nl_search", user: current_user)

        neighbors = ListingEmbedding
          .nearest_neighbors(:embedding, vector, distance: :cosine)
          .includes(rv_listing: [ :owner, { images_attachments: :blob } ])
          .limit(SEARCH_LIMIT)

        results = neighbors.map do |embedding|
          embedding.rv_listing.as_json.merge("score" => embedding.neighbor_distance)
        end

        render json: results
      rescue Ai::ApiError => e
        render json: { status: "error", message: e.message }, status: :service_unavailable
      end

      def mine
        @listings = current_user.rv_listings
        render json: @listings
      end

      def show
        render json: @listing
      end

      def create
        @listing = current_user.rv_listings.build(listing_params)
        if @listing.save
          render json: @listing, status: :created
        else
          render_unprocessable(@listing)
        end
      end

      def update
        if @listing.update(update_listing_params)
          render json: @listing
        else
          render_unprocessable(@listing)
        end
      end

      def destroy
        @listing.destroy
        head :no_content
      end

      private

      def set_listing
        @listing = RvListing.find(params[:id])
      end

      def authorize_owner!
        return if @listing.owner_id == current_user.id
        render json: { error: "Not authorized" }, status: :forbidden
      end

      LISTING_FIELDS = %i[title description rv_type town state postcode price_per_day max_guests pet_friendly latitude longitude].freeze

      def listing_params
        params.require(:listing).permit(*LISTING_FIELDS, images: [])
      end

      def update_listing_params
        params.require(:listing).permit(*LISTING_FIELDS)
      end
    end
  end
end
