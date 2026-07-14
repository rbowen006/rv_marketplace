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

      AiRequest.create!(
        feature:           prompt_feature,
        model:             model,
        prompt_version:    prompt_version,
        input_tokens:      @input_tokens,
        output_tokens:     @output_tokens,
        latency_ms:        latency_ms,
        estimated_cost_usd: cost,
        success:           @error.nil?,
        error_message:     @error&.message,
        request_payload:   @request_payload,
        response_payload:  @response_payload,
        user:              @user
      )
    rescue => e
      Rails.logger.error("Failed to write ai_request: #{e.message}")
    end

    def cost
      return nil unless @input_tokens && @output_tokens
      Ai::Pricing.cost_for(model: model, input_tokens: @input_tokens, output_tokens: @output_tokens)
    end
  end
end
