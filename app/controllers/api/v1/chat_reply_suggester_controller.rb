module Api
  module V1
    class ChatReplySuggesterController < BaseController
      # Cap paid Claude calls per user (see ADR-0010). Separate 10/hr bucket from
      # the description generator — each AI feature has its own budget.
      RATE_LIMIT_WINDOW = 1.hour

      rate_limit to: 10, within: RATE_LIMIT_WINDOW,
                 by: -> { current_user.id },
                 with: -> { render_rate_limited }

      def create
        chat = Chat.find(params[:id])
        return render json: { status: "fail", message: "Forbidden" }, status: :forbidden unless chat.owner_id == current_user.id

        unless chat.messages.exists?(user_id: chat.hirer_id)
          return render json: { status: "fail", message: "No hirer message to reply to yet." },
                        status: :unprocessable_content
        end

        data = Ai::ChatReplySuggester.call(chat: chat, user: current_user)
        render json: { status: "success", data: data }, status: :ok
      rescue Ai::InputError => e
        render json: { status: "fail", message: e.message }, status: :bad_request
      rescue Ai::ApiError => e
        render json: { status: "error", message: e.message }, status: :service_unavailable
      rescue Ai::OutputError => e
        render json: { status: "error", message: e.message }, status: :internal_server_error
      end

      private

      def render_rate_limited
        response.set_header("Retry-After", RATE_LIMIT_WINDOW.to_i.to_s)
        render json: { status: "fail", message: "Rate limit exceeded. Please try again later." },
               status: :too_many_requests
      end
    end
  end
end
