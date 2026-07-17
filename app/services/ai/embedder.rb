require "net/http"
require "json"

module Ai
  # Wraps the local Ollama embeddings endpoint so the provider detail lives in
  # one place (ADR-0011). Not a BaseAiService subclass: there is no prompt file
  # and no output schema, so that base class is a poor fit. Every call writes an
  # ai_requests row (cost $0) in an ensure block, mirroring BaseAiService.
  #
  #   Ai::Embedder.call("some text", feature: "nl_search") # => [768 floats]
  class Embedder
    MODEL = "nomic-embed-text"

    def self.call(text, feature:, user: nil)
      new(text, feature: feature, user: user).call
    end

    def initialize(text, feature:, user: nil)
      @text    = text
      @feature = feature
      @user    = user
    end

    def call
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @error = nil

      embedding = request_embedding
      embedding
    rescue Ai::Error => e
      @error = e
      raise
    rescue => e
      @error = Ai::ApiError.new("Unexpected error (#{e.class}): #{e.message}")
      raise @error
    ensure
      write_ai_request
    end

    private

    def request_embedding
      uri = URI.join(base_url, "/api/embeddings")
      response = Net::HTTP.post(
        uri,
        { model: MODEL, prompt: @text }.to_json,
        "Content-Type" => "application/json"
      )

      unless response.is_a?(Net::HTTPSuccess)
        raise Ai::ApiError, "Ollama embeddings error (#{response.code}): #{response.body}"
      end

      JSON.parse(response.body).fetch("embedding")
    rescue Ai::Error
      raise
    rescue => e
      raise Ai::ApiError, "Ollama embeddings error: #{e.message}"
    end

    # Deliberately NOT Ai::RequestLogging, despite the near-duplication (#71).
    # Including that module is what marks a service as making *paid* calls priced
    # through Ai::Pricing — the RATES-coverage spec keys off exactly that to find
    # unpriced models (spec/services/ai/pricing_spec.rb). Ollama runs locally and
    # is free, so sharing the writer would drag nomic-embed-text into the priced
    # set and demand a rate for a model that has no price, forcing an exception
    # by name. This copy is the cheaper half of that trade: it writes only the
    # columns a free, promptless, token-less call can fill.
    def write_ai_request
      latency_ms = @started_at ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round : nil

      AiRequest.create!(
        feature:            @feature,
        model:              MODEL,
        prompt_version:     nil,
        latency_ms:         latency_ms,
        estimated_cost_usd: 0.0,
        success:            @error.nil?,
        error_message:      @error&.message,
        user:               @user
      )
    rescue => e
      Rails.logger.error("Failed to write ai_request: #{e.message}")
    end

    def base_url
      ENV.fetch("OLLAMA_URL", "http://ollama:11434")
    end
  end
end
