module Api
  module V1
    class MessagesController < BaseController
      before_action :set_chat
      before_action :authorize_participant!

      def index
        messages = @chat.messages.order(:created_at)
        mark_messages_read
        render json: messages
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

      def mark_messages_read
        now = Time.current
        @chat.messages.where.not(user_id: current_user.id).where(read_at: nil).update_all(read_at: now)
        read_at_field = @chat.hirer_id == current_user.id ? :hirer_last_read_at : :owner_last_read_at
        @chat.update_column(read_at_field, now)
      end

      def message_params
        params.require(:message).permit(:content)
      end
    end
  end
end
