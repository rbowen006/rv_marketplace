module Ai
  # Shared observability seam (ADR-0014 §Service structure). Writes exactly one
  # ai_requests row per Claude call — the brief's mandated per-call cost/token
  # record — so the single-shot BaseAiService path and the agent-loop path share
  # one writer and can't silently drift on columns or cost math. Reads the host's
  # timing/token/error ivars and its model/prompt_feature/prompt_version.
  module RequestLogging
    private

    def write_ai_request
      latency_ms = @started_at ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round : nil
      # Held in a local so the rescue below reports it without re-running the
      # computation that may be why we are in the rescue at all.
      estimated_cost = cost

      attrs = {
        feature:           prompt_feature,
        model:             model,
        prompt_version:    prompt_version,
        input_tokens:      @input_tokens,
        output_tokens:     @output_tokens,
        latency_ms:        latency_ms,
        estimated_cost_usd: estimated_cost,
        success:           @error.nil?,
        error_message:     @error&.message,
        request_payload:   @request_payload,
        response_payload:  @response_payload,
        user:              @user,
        conversation_id:   @conversation_id
      }

      # Nested, not a sibling rescue: an exception raised in a sibling clause
      # escapes the method, and this runs in invoke_claude's ensure, where it
      # would replace the real error propagating.
      begin
        AiRequest.create!(**attrs)
      rescue ActiveRecord::InvalidForeignKey => e
        # "Start over" destroyed the conversation mid-turn (#65). The call is
        # already billed, so keep the spend and drop the dangling link — the same
        # state dependent: :nullify gives every row written before the destroy.
        # Only the conversation link is droppable; any other FK violation stands.
        raise e if @conversation_id.nil?

        AiRequest.create!(**attrs.merge(conversation_id: nil))
      end
    rescue => e
      # Never raise (see above). Log the spend itself, not just the error: this
      # line is all that survives of a row we failed to write.
      Rails.logger.error(
        "Failed to write ai_request (#{e.class}: #{e.message}) " \
        "feature=#{prompt_feature} model=#{model} cost=#{estimated_cost} user=#{@user&.id}"
      )
    end

    def cost
      return nil unless @input_tokens && @output_tokens
      Ai::Pricing.cost_for(model: model, input_tokens: @input_tokens, output_tokens: @output_tokens)
    end
  end
end
