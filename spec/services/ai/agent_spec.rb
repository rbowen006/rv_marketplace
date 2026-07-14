require 'rails_helper'

module Ai
  # A minimal concrete agent for exercising the base loop mechanics in isolation
  # from the real concierge tools.
  class SpecAgent < Agent
    MODEL = "claude-sonnet-5"
    MAX_TOKENS = 1024
    PROMPT_FEATURE = "spec_agent"
    PROMPT_VERSION = "v1"

    def system_prompt
      "You are a test agent."
    end

    def tool_definitions
      [{
        name: "echo",
        description: "Echoes its message back.",
        input_schema: {
          "type" => "object",
          "required" => ["message"],
          "properties" => { "message" => { "type" => "string" } }
        }
      }]
    end

    def call_tool(name, input)
      raise Ai::InputError, "unknown tool: #{name}" unless name == "echo"

      { echoed: input.fetch("message") }
    end
  end
end

RSpec.describe Ai::Agent do
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user: user) }

  def stub_claude(*bodies)
    responses = bodies.map do |b|
      { status: 200, body: b.to_json, headers: { "Content-Type" => "application/json" } }
    end
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(*responses)
  end

  def text_turn(text)
    {
      id: "msg_1", type: "message", role: "assistant",
      content: [{ type: "text", text: text }],
      model: "claude-sonnet-5", stop_reason: "end_turn",
      usage: { input_tokens: 50, output_tokens: 10 }
    }
  end

  def tool_use_turn(tool_name, input, id: "toolu_1")
    {
      id: "msg_2", type: "message", role: "assistant",
      content: [{ type: "tool_use", id: id, name: tool_name, input: input }],
      model: "claude-sonnet-5", stop_reason: "tool_use",
      usage: { input_tokens: 60, output_tokens: 15 }
    }
  end

  it "runs a single turn and logs one ai_request tagged with the conversation" do
    stub_claude(text_turn("Hello!"))

    messages = nil
    expect { messages = Ai::SpecAgent.new(conversation: conversation).run("hi") }
      .to change(AiRequest, :count).by(1)

    expect(messages.last["role"]).to eq("assistant")
    row = AiRequest.last
    expect(row.feature).to eq("spec_agent")
    expect(row.conversation_id).to eq(conversation.id)
    expect(row.user).to eq(user)
    expect(row.input_tokens).to eq(50)
  end

  it "dispatches a tool call, feeds the structured result back, and logs a row per call" do
    stub_claude(
      tool_use_turn("echo", { "message" => "ping" }),
      text_turn("done")
    )

    messages = nil
    expect { messages = Ai::SpecAgent.new(conversation: conversation).run("say ping") }
      .to change(AiRequest, :count).by(2)

    tool_turn = messages.find { |m| m["role"] == "user" && m["content"].is_a?(Array) }
    block = tool_turn["content"].first
    expect(block["type"]).to eq("tool_result")
    expect(block["tool_use_id"]).to eq("toolu_1")
    expect(JSON.parse(block["content"])).to eq({ "echoed" => "ping" })

    expect(messages.last["role"]).to eq("assistant")
  end

  it "stops after MAX_ITERATIONS when the model never finishes the turn" do
    stub_claude(tool_use_turn("echo", { "message" => "loop" }))

    agent = Ai::SpecAgent.new(conversation: conversation)

    expect {
      expect { agent.run("go") }.to raise_error(Ai::ApiError, /MAX_ITERATIONS/)
    }.to change(AiRequest, :count).by(Ai::Agent::MAX_ITERATIONS)
  end

  it "returns an is_error tool_result for a bad tool call instead of crashing the turn" do
    stub_claude(
      tool_use_turn("nonexistent", {}),
      text_turn("recovered")
    )

    messages = Ai::SpecAgent.new(conversation: conversation).run("break it")

    tool_turn = messages.find { |m| m["role"] == "user" && m["content"].is_a?(Array) }
    block = tool_turn["content"].first
    expect(block["is_error"]).to be true
    expect(block["content"]).to match(/unknown tool/)
    expect(messages.last["role"]).to eq("assistant")
  end

  it "disables thinking and caches the stable prefix (system + tools)" do
    stub_claude(text_turn("hi"))

    Ai::SpecAgent.new(conversation: conversation).run("hello")

    expect(
      a_request(:post, "https://api.anthropic.com/v1/messages").with { |req|
        body = JSON.parse(req.body)
        body.dig("thinking", "type") == "disabled" &&
          body["system"].is_a?(Array) &&
          body["system"].last["cache_control"] == { "type" => "ephemeral" }
      }
    ).to have_been_made
  end

  it "logs a failure row and raises ApiError when the Claude call errors" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 400,
      body: { type: "error", error: { type: "invalid_request_error", message: "bad" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    agent = Ai::SpecAgent.new(conversation: conversation)

    expect {
      expect { agent.run("hi") }.to raise_error(Ai::ApiError)
    }.to change(AiRequest, :count).by(1)
    expect(AiRequest.last.success).to be false
  end

  it "ends the turn on a non-tool_use stop reason instead of re-looping" do
    stub_claude(text_turn("partial answer").merge(stop_reason: "max_tokens"))

    messages = nil
    expect { messages = Ai::SpecAgent.new(conversation: conversation).run("hi") }
      .to change(AiRequest, :count).by(1)
    expect(messages.last["role"]).to eq("assistant")
  end
end
