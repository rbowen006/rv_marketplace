module Ai
  # Base class for the app's agentic tool-use loop (ADR-0014). Runs a hand-written
  # loop over the stable client.messages.create surface: call Claude, and while it
  # returns stop_reason :tool_use, dispatch the requested tools, append their
  # results as structured JSON, and call again — until :end_turn. One call per
  # iteration writes one ai_requests row (via RequestLogging), tagged with the
  # conversation so a turn's N rows group cleanly. Subclasses supply the concrete
  # system prompt, tool definitions, and tool dispatch; the loop mechanics,
  # per-call logging, iteration cap, and prompt-injection framing live here.
  #
  # Subclasses define the constants MODEL, MAX_TOKENS, PROMPT_FEATURE,
  # PROMPT_VERSION and implement #system_prompt, #tool_definitions, #call_tool.
  class Agent
    include Ai::RequestLogging

    MAX_ITERATIONS = 8

    def initialize(conversation:)
      @conversation = conversation
      @user = conversation.user
      @conversation_id = conversation.id
    end

    # Runs one turn to completion and returns the full transcript array (the
    # caller persists it as the conversation's source of truth). Pass a
    # user_message to start a fresh turn; omit it to continue the loop from a
    # transcript whose user message the caller already appended and persisted.
    def run(user_message = nil)
      @messages = @conversation.transcript.map(&:dup)
      @messages << { "role" => "user", "content" => user_message } if user_message

      report_step(initial_step)
      iterations = 0
      loop do
        iterations += 1
        raise Ai::ApiError, "Agent exceeded MAX_ITERATIONS (#{MAX_ITERATIONS})" if iterations > MAX_ITERATIONS

        response = invoke_claude
        @messages << { "role" => "assistant", "content" => response.content.map { |block| serialize_block(block) } }

        # Only a tool_use turn continues the loop. end_turn, and any other stop
        # reason (max_tokens, refusal, pause_turn), is terminal — the assistant
        # content so far is the final answer rather than a cue to call again.
        break unless response.stop_reason == :tool_use

        report_step(step_label(tool_names(response)))
        @messages << { "role" => "user", "content" => tool_results(response) }
      end

      @messages
    end

    private

    # Progress line the poller surfaces while the turn runs (ADR-0014 §Transport).
    # Subclasses map tool names to friendly labels via #step_label.
    def report_step(label)
      @conversation.update_column(:step_status, label)
    end

    def initial_step
      "Thinking…"
    end

    def step_label(_tool_names)
      "Working…"
    end

    def tool_names(response)
      response.content.select { |block| block.type == :tool_use }.map(&:name)
    end

    # Minimal, request-valid serialization of a response content block. block.to_h
    # leaks SDK-only fields (e.g. caller_) that the API rejects when the assistant
    # turn is re-sent; keep only what each block type needs, string-keyed so the whole
    # transcript is uniform.
    def serialize_block(block)
      case block.type
      when :text
        { "type" => "text", "text" => block.text }
      when :tool_use
        { "type" => "tool_use", "id" => block.id, "name" => block.name,
          "input" => block.input.to_h.deep_stringify_keys }
      else
        block.to_h.deep_stringify_keys
      end
    end

    def model
      self.class::MODEL
    end

    def max_tokens
      self.class::MAX_TOKENS
    end

    def prompt_feature
      self.class::PROMPT_FEATURE
    end

    def prompt_version
      self.class::PROMPT_VERSION
    end

    # System prompt as a single cached text block. Render order is tools ->
    # system -> messages, so one cache_control breakpoint here caches the whole
    # stable prefix (system + tool schemas); loop iterations 2..N read it at
    # ~0.1x instead of full price (ADR-0014 §Model build note).
    def system_blocks
      [{ type: "text", text: system_prompt, cache_control: { type: "ephemeral" } }]
    end

    def client
      @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    end

    def invoke_claude
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @error = nil

      response = client.messages.create(
        model: model,
        max_tokens: max_tokens,
        thinking: { type: "disabled" },
        system_: system_blocks,
        tools: tool_definitions,
        messages: @messages
      )

      @input_tokens  = response.usage.input_tokens
      @output_tokens = response.usage.output_tokens
      response
    rescue Ai::Error => e
      @error = e
      raise
    rescue => e
      @error = Ai::ApiError.new("Claude API error (#{e.class}): #{e.message}")
      raise @error
    ensure
      write_ai_request
    end

    # Dispatches every tool_use block in the assistant turn and returns the
    # matching tool_result blocks. Results are structured JSON — untrusted
    # owner-authored text (e.g. a listing blurb) is framed as data, never
    # interpolated as instructions (ADR-0014 §Guardrails). A bad tool input is
    # returned as an is_error result so the agent recovers and the job never
    # crashes.
    def tool_results(response)
      response.content.select { |block| block.type == :tool_use }.map do |block|
        result = call_tool(block.name, block.input.to_h.deep_stringify_keys)
        { "type" => "tool_result", "tool_use_id" => block.id, "content" => result.to_json }
      rescue Ai::InputError => e
        { "type" => "tool_result", "tool_use_id" => block.id, "content" => e.message, "is_error" => true }
      end
    end
  end
end
