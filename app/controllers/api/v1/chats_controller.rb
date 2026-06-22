module Api
  module V1
    class ChatsController < BaseController
      def create
        listing = RvListing.find(params[:listing_id])
        chat = Chat.find_or_initialize_unbooked(current_user, listing.owner)

        if chat.persisted?
          chat.update!(rv_listing: listing)
          status = :ok
        else
          chat.hirer = current_user
          chat.owner = listing.owner
          chat.rv_listing = listing
          chat.save!
          status = :created
        end

        chat.messages.create!(user: current_user, content: message_params[:content])
        render json: chat.as_json(include_messages: true), status: status
      end

      private

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
