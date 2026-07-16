module Ai
  # The AI Concierge (ADR-0014): a conversational discovery agent over the RV
  # catalogue. Supplies the concrete pieces the Ai::Agent loop needs — the
  # claude-sonnet-5 override (the app's only agentic feature), the versioned
  # system prompt, and the five read-only tools plus the recommend_listings
  # output channel. All loop mechanics, per-call logging, the iteration cap, and
  # prompt-injection framing live in Ai::Agent.
  class Concierge < Ai::Agent
    MODEL = "claude-sonnet-5"
    MAX_TOKENS = 1024
    PROMPT_FEATURE = "concierge"
    PROMPT_VERSION = "v1"

    TOOLS = [
      Ai::Tools::SearchListings,
      Ai::Tools::GetListingDetail,
      Ai::Tools::CheckAvailability,
      Ai::Tools::CalculatePrice,
      Ai::Tools::RecommendListings
    ].freeze

    STEP_LABELS = {
      "search_listings"    => "Searching listings…",
      "get_listing_detail" => "Looking up details…",
      "check_availability" => "Checking availability…",
      "calculate_price"    => "Working out the price…",
      "recommend_listings" => "Picking recommendations…"
    }.freeze

    private

    def step_label(tool_names)
      STEP_LABELS.values_at(*tool_names).compact.first || super
    end

    def system_prompt
      load_prompt
    end

    def tool_definitions
      TOOLS.map { |tool| tool::DEFINITION }
    end

    # search_listings gets the user so its embedding call is attributed; the
    # other tools take only their input.
    def call_tool(name, input)
      case name
      when "search_listings"    then Ai::Tools::SearchListings.call(input, user: @user)
      when "get_listing_detail" then Ai::Tools::GetListingDetail.call(input)
      when "check_availability" then Ai::Tools::CheckAvailability.call(input)
      when "calculate_price"    then Ai::Tools::CalculatePrice.call(input)
      when "recommend_listings" then Ai::Tools::RecommendListings.call(input)
      else raise Ai::InputError, "Unknown tool: #{name}"
      end
    end

    # Load the versioned system prompt from app/prompts/<feature>/<version>.txt.
    # A small copy of BaseAiService's loader, kept duplicated on purpose (PR #48):
    # the shared seam is the ai_requests writer, not this File.read.
    def load_prompt
      File.read(Rails.root.join("app", "prompts", prompt_feature, "#{prompt_version}.txt"))
    rescue Errno::ENOENT
      raise Ai::ApiError, "Prompt file not found: #{prompt_feature}/#{prompt_version}.txt"
    end
  end
end
