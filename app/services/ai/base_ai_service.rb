module Ai
  class BaseAiService
    DEFAULT_MODEL = "claude-sonnet-4-6"

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def call
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @error = nil

      validate_input!
      prompt = load_prompt
      message = build_user_message
      response = invoke_claude(prompt, message)
      data = parse_and_validate(response)
      data
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

    def model
      self.class::MODEL
    rescue NameError
      DEFAULT_MODEL
    end

    def prompt_feature
      self.class::PROMPT_FEATURE
    end

    def prompt_version
      self.class::PROMPT_VERSION
    end

    def load_prompt
      path = Rails.root.join("app", "prompts", prompt_feature, "#{prompt_version}.txt")
      File.read(path)
    rescue Errno::ENOENT
      raise Ai::ApiError, "Prompt file not found: #{prompt_feature}/#{prompt_version}.txt"
    end

    def invoke_claude(system_prompt, user_message)
      client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      message_json = user_message.to_json

      response = client.messages.create(
        model: model,
        max_tokens: 1024,
        system: system_prompt,
        messages: [
          { role: "user", content: message_json }
        ]
      )

      content_block = response.content.first
      unless content_block.respond_to?(:text)
        raise Ai::ApiError, "Claude did not return text content (stop_reason: #{response.stop_reason})"
      end

      @input_tokens     = response.usage.input_tokens
      @output_tokens    = response.usage.output_tokens
      @request_payload  = message_json
      @response_payload = content_block.text

      content_block.text
    rescue Ai::Error
      raise
    rescue => e
      raise Ai::ApiError, "Claude API error: #{e.message}"
    end

    def parse_and_validate(raw_json)
      data = JSON.parse(raw_json)
      errors = JSON::Validator.fully_validate(output_schema, data)
      unless errors.empty?
        raise Ai::OutputError, "Output schema validation failed: #{errors.first}"
      end
      data
    rescue JSON::ParserError => e
      raise Ai::OutputError, "Claude returned invalid JSON: #{e.message}"
    end

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
