module Api
  module V1
    # AI Concierge (ADR-0014): one active conversation per user. POST enqueues a
    # background turn; the frontend polls GET for status, messages, and recommended
    # listings; DELETE resets ("start over").
    class ConciergeController < BaseController
      MESSAGE_MAX_LENGTH = 1500
      RATE_LIMIT_WINDOW = 1.hour

      # Cap paid turns per user (ADR-0010 macro), own bucket. create only — the
      # poll GET must never be throttled.
      rate_limit to: 15, within: RATE_LIMIT_WINDOW,
                 by: -> { current_user.id },
                 with: -> { render_rate_limited },
                 only: :create

      # GET /api/v1/concierge
      def show
        conversation = current_user.concierge_conversation
        return render json: { status: "success", data: { status: "none" } } if conversation.nil?

        render_conversation(conversation)
      end

      # POST /api/v1/concierge/messages
      def create
        message = params[:message].to_s.strip
        if message.blank?
          return render json: { status: "fail", message: "Message can't be blank." }, status: :bad_request
        end
        if message.length > MESSAGE_MAX_LENGTH
          return render json: { status: "fail", message: "Message is too long." }, status: :bad_request
        end

        conversation = ConciergeConversation.find_or_create_by!(user: current_user)

        if conversation.processing?
          return render json: { status: "fail", message: "I'm still working on your last message." },
                        status: :conflict
        end

        # Persist the user message before the (fallible) turn so it survives a
        # failure, then hand off to the background job. Retrying a failed turn
        # re-runs the same trailing message rather than duplicating it.
        new_message = { "role" => "user", "content" => message }
        retrying = conversation.failed? && conversation.transcript.last == new_message
        transcript = retrying ? conversation.transcript : conversation.transcript + [new_message]

        conversation.update!(status: :processing, step_status: "Thinking…", error: nil, transcript: transcript)
        ConciergeTurnJob.perform_later(conversation.id)

        render_conversation(conversation, status: :accepted)
      rescue ActiveRecord::RecordNotUnique
        # A concurrent request created the conversation first.
        render json: { status: "fail", message: "I'm still working on your last message." }, status: :conflict
      end

      # DELETE /api/v1/concierge
      def destroy
        current_user.concierge_conversation&.destroy
        render json: { status: "success", data: { status: "none" } }
      end

      private

      def render_conversation(conversation, status: :ok)
        render json: {
          status: "success",
          data: {
            status:          conversation.status,
            step_status:     conversation.step_status,
            error:           conversation.error,
            messages:        display_messages(conversation.transcript),
            recommendations: recommendations(conversation.transcript)
          }
        }, status: status
      end

      # The durable transcript holds tool blocks too; the display view is just the
      # user text and assistant text (ADR-0014 §Conversation state).
      def display_messages(transcript)
        transcript.filter_map do |entry|
          case entry["role"]
          when "user"
            { role: "user", text: entry["content"] } if entry["content"].is_a?(String)
          when "assistant"
            text = assistant_text(entry["content"])
            { role: "assistant", text: text } if text.present?
          end
        end
      end

      def assistant_text(content)
        Array(content).select { |block| block["type"] == "text" }.map { |block| block["text"] }.join("\n").strip
      end

      # Recommendations are the ids from the most recent recommend_listings tool
      # call, hydrated into real listings (ordered as recommended; skips any that
      # since disappeared).
      def recommendations(transcript)
        ids = latest_recommended_ids(transcript)
        return [] if ids.empty?

        by_id = RvListing.where(id: ids).index_by(&:id)
        ids.filter_map { |id| by_id[id]&.as_json }
      end

      def latest_recommended_ids(transcript)
        transcript.reverse_each do |entry|
          next unless entry["role"] == "assistant"

          call = Array(entry["content"]).find { |block| block["type"] == "tool_use" && block["name"] == "recommend_listings" }
          return Array(call.dig("input", "listing_ids")).map(&:to_i) if call
        end
        []
      end

      def render_rate_limited
        response.set_header("Retry-After", RATE_LIMIT_WINDOW.to_i.to_s)
        render json: { status: "fail", message: "Rate limit exceeded. Please try again later." },
               status: :too_many_requests
      end
    end
  end
end
