module Api
  module V1
    class ChatsController < BaseController
      def index
        as_hirer = chats_for_role(:hirer)
        as_owner = chats_for_role(:owner)
        render json: { as_hirer: as_hirer, as_owner: as_owner }
      end

      def show
        @chat = Chat.find(params[:id])
        unless @chat.hirer_id == current_user.id || @chat.owner_id == current_user.id
          return render json: { error: 'Forbidden' }, status: :forbidden
        end
        render json: @chat.as_json(include_messages: true, include_participants: true)
      end

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

      def chats_for_role(role)
        id_field = role == :hirer ? :hirer_id : :owner_id
        Chat.where(id_field => current_user.id)
            .order(last_message_at: :desc)
            .includes(:hirer, :owner, :rv_listing)
            .map { |c| c.as_json(include_participants: true) }
      end

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
