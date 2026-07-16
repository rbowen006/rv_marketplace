module Ai
  class BaseAiService
    include Ai::RequestLogging

    DEFAULT_MODEL = "claude-sonnet-4-6"
    DEFAULT_MAX_TOKENS = 1024

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

    def max_tokens
      self.class::MAX_TOKENS
    rescue NameError
      DEFAULT_MAX_TOKENS
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
        max_tokens: max_tokens,
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
      data = JSON.parse(strip_code_fence(raw_json))
      errors = JSON::Validator.fully_validate(output_schema, data)
      unless errors.empty?
        raise Ai::OutputError, "Output schema validation failed: #{errors.first}"
      end
      data
    rescue JSON::ParserError => e
      raise Ai::OutputError, "Claude returned invalid JSON: #{e.message}"
    end

    # Claude sometimes wraps structured output in a ```json … ``` fence despite
    # being asked for raw JSON. Strip a single leading/trailing fence so the
    # parse succeeds; leave already-clean JSON untouched.
    def strip_code_fence(text)
      stripped = text.to_s.strip
      return stripped unless stripped.start_with?("```")

      stripped.sub(/\A```[a-zA-Z0-9]*[ \t]*\r?\n?/, "").sub(/\r?\n?```\z/, "")
    end

  end
end
