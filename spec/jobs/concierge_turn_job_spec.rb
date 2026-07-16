require 'rails_helper'

RSpec.describe ConciergeTurnJob do
  let(:user) { create(:user) }
  let(:conversation) do
    ConciergeConversation.create!(
      user: user, status: :processing, step_status: "Thinking…",
      transcript: [ { "role" => "user", "content" => "find me a van" } ]
    )
  end

  def end_turn_body(text)
    {
      id: "m", type: "message", role: "assistant",
      content: [ { type: "text", text: text } ],
      model: "claude-sonnet-5", stop_reason: "end_turn",
      usage: { input_tokens: 10, output_tokens: 5 }
    }
  end

  it "runs the turn, persists the transcript, and returns the conversation to idle" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: end_turn_body("Here are some options").to_json,
                 headers: { "Content-Type" => "application/json" })

    described_class.new.perform(conversation.id)

    conversation.reload
    expect(conversation).to be_idle
    expect(conversation.step_status).to be_nil
    expect(conversation.error).to be_nil
    expect(conversation.transcript.last["role"]).to eq("assistant")
  end

  it "marks the conversation failed with an error message when the turn errors" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 400,
                 body: { type: "error", error: { type: "invalid_request_error", message: "bad" } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    described_class.new.perform(conversation.id)

    conversation.reload
    expect(conversation).to be_failed
    expect(conversation.error).to be_present
    expect(conversation.step_status).to be_nil
  end
end
