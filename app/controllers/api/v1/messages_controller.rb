module Api
  module V1
    class MessagesController < BaseController
      before_action :set_listing

      def index
        @messages = @listing.messages
        render json: @messages
      end

      def create
        @message = @listing.messages.build(message_params)
        @message.user = current_user
        if @message.save
          render json: @message, status: :created
        else
          render_unprocessable(@message)
        end
      end

      private

      def set_listing
        @listing = RvListing.find(params[:listing_id])
      end

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
