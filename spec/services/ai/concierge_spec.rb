require 'rails_helper'

RSpec.describe Ai::Concierge do
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user: user) }

  def stub_claude(*bodies)
    responses = bodies.map do |b|
      { status: 200, body: b.to_json, headers: { "Content-Type" => "application/json" } }
    end
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(*responses)
  end

  def end_turn(text)
    {
      id: "m", type: "message", role: "assistant",
      content: [ { type: "text", text: text } ],
      model: "claude-sonnet-5", stop_reason: "end_turn",
      usage: { input_tokens: 10, output_tokens: 5 }
    }
  end

  def recommend_turn(ids)
    {
      id: "m", type: "message", role: "assistant",
      content: [ { type: "tool_use", id: "toolu_1", name: "recommend_listings", input: { listing_ids: ids } } ],
      model: "claude-sonnet-5", stop_reason: "tool_use",
      usage: { input_tokens: 20, output_tokens: 8 }
    }
  end

  it "sends the versioned concierge prompt and all five tools on claude-sonnet-5" do
    stub_claude(end_turn("hi"))

    Ai::Concierge.new(conversation: conversation).run("help me find a van")

    expect(
      a_request(:post, "https://api.anthropic.com/v1/messages").with { |req|
        body = JSON.parse(req.body)
        tool_names = body["tools"].map { |t| t["name"] }.sort
        body["model"] == "claude-sonnet-5" &&
          body["system"].first["text"] == File.read(Rails.root.join("app/prompts/concierge/v1.txt")) &&
          tool_names == %w[calculate_price check_availability get_listing_detail recommend_listings search_listings]
      }
    ).to have_been_made
  end

  it "dispatches a real tool call and logs each call under the concierge feature" do
    listing = create(:rv_listing)
    stub_claude(recommend_turn([ listing.id ]), end_turn("Here you go"))

    messages = nil
    expect { messages = Ai::Concierge.new(conversation: conversation).run("show me one") }
      .to change(AiRequest, :count).by(2)

    tool_turn = messages.find { |m| m["role"] == "user" && m["content"].is_a?(Array) }
    ack = JSON.parse(tool_turn["content"].first["content"])
    expect(ack).to eq("recommended" => [ listing.id ])
    expect(AiRequest.where(feature: "concierge").last.model).to eq("claude-sonnet-5")
    expect(conversation.reload.step_status).to eq("Picking recommendations…")
  end
end
