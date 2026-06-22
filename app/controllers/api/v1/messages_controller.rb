module Api
  module V1
    class MessagesController < BaseController
      before_action :set_chat
      before_action :authorize_participant!

      def index
        render json: @chat.messages.order(:created_at)
      end

      def create
        message = @chat.messages.build(message_params)
        message.user = current_user
        if message.save
          render json: message, status: :created
        else
          render_unprocessable(message)
        end
      end

      private

      def set_chat
        @chat = Chat.find(params[:chat_id])
      end

      def authorize_participant!
        unless @chat.hirer_id == current_user.id || @chat.owner_id == current_user.id
          render json: { error: 'Forbidden' }, status: :forbidden
        end
      end

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
