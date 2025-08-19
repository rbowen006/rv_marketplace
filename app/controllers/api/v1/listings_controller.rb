module Api
  module V1
    class ListingsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]
      before_action :set_listing, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:update, :destroy]

      def index
        @listings = RvListing.all
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
        if @listing.update(listing_params)
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
        return if @listing.user_id == current_user.id
        render json: { error: 'Not authorized' }, status: :forbidden
      end

      def listing_params
        params.require(:listing).permit(:title, :description, :location, :price_per_day)
      end
    end
  end
end
