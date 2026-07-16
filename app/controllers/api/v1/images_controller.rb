module Api
  module V1
    class ImagesController < BaseController
      before_action :set_listing
      before_action :authorize_owner!

      def create
        @listing.images.attach(params[:images])
        render json: @listing, status: :created
      end

      def destroy
        attachment = @listing.images.attachments.find(params[:id])
        attachment.purge_later
        head :no_content
      end

      private

      def set_listing
        @listing = RvListing.find(params[:listing_id])
      end

      def authorize_owner!
        return if @listing.owner_id == current_user.id

        render json: { error: "Not authorized" }, status: :forbidden
      end
    end
  end
end
