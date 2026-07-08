require 'rails_helper'

RSpec.describe Ai::ChatReplySuggester do
  let(:owner) { create(:user) }
  let(:hirer) { create(:user) }
  let(:rv_listing) { create(:rv_listing, owner: owner) }
  let(:chat) { create(:chat, owner: owner, hirer: hirer, rv_listing: rv_listing) }

  let(:anthropic_success_body) do
    {
      id: "msg_123",
      type: "message",
      role: "assistant",
      content: [ { type: "text", text: '{"reply":"Yes, the van is pet friendly!"}' } ],
      model: "claude-sonnet-4-6",
      stop_reason: "end_turn",
      usage: { input_tokens: 200, output_tokens: 20 }
    }.to_json
  end

  before do
    create(:message, chat: chat, user: hirer, content: "Is the van pet friendly?")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  # Parses the payload the service sent to Claude (the user turn's JSON content).
  def sent_payload
    captured = nil
    expect(
      a_request(:post, "https://api.anthropic.com/v1/messages").with { |req| captured = req.body; true }
    ).to have_been_made
    JSON.parse(JSON.parse(captured)["messages"].first["content"])
  end

  describe ".call" do
    it "returns the suggested reply and logs a chat_reply request" do
      expect {
        result = Ai::ChatReplySuggester.call(chat: chat, user: owner)
        expect(result["reply"]).to eq("Yes, the van is pet friendly!")
      }.to change(AiRequest, :count).by(1)

      record = AiRequest.last
      expect(record.feature).to eq("chat_reply")
      expect(record.success).to be true
      expect(record.user).to eq(owner)
    end

    it "sends the conversation as role-labelled messages in chronological order" do
      create(:message, chat: chat, user: owner, content: "Hi, happy to help!")
      create(:message, chat: chat, user: hirer, content: "Great, is it available in July?")

      Ai::ChatReplySuggester.call(chat: chat, user: owner)

      messages = sent_payload["messages"]
      expect(messages.map { |m| m["role"] }).to eq(%w[hirer owner hirer])
      expect(messages.map { |m| m["content"] }).to eq([
        "Is the van pet friendly?",
        "Hi, happy to help!",
        "Great, is it available in July?"
      ])
    end

    it "sends only the 10 most recent messages" do
      # before-block already added 1 message ("Is the van pet friendly?"); add 11 more (12 total)
      11.times { |i| create(:message, chat: chat, user: hirer, content: "msg #{i}") }

      Ai::ChatReplySuggester.call(chat: chat, user: owner)

      contents = sent_payload["messages"].map { |m| m["content"] }
      expect(contents.length).to eq(10)
      expect(contents).to include("msg 10")           # most recent kept
      expect(contents).not_to include("Is the van pet friendly?") # oldest dropped
    end

    it "truncates an over-long message to 500 characters" do
      create(:message, chat: chat, user: hirer, content: "a" * 600)

      Ai::ChatReplySuggester.call(chat: chat, user: owner)

      long = sent_payload["messages"].last["content"]
      expect(long.length).to eq(500)
      expect(long).to end_with("…")
    end

    it "includes the listing's structured facts" do
      rv_listing.update!(
        title: "Cosy Coastal Caravan", description: "A gem by the sea.",
        rv_type: :motorhome, town: "Byron Bay", state: "NSW",
        max_guests: 6, pet_friendly: true, price_per_day: 175.0
      )

      Ai::ChatReplySuggester.call(chat: chat, user: owner)

      expect(sent_payload["listing"]).to eq(
        "title"         => "Cosy Coastal Caravan",
        "description"   => "A gem by the sea.",
        "rv_type"       => "motorhome",
        "town"          => "Byron Bay",
        "state"         => "NSW",
        "max_guests"    => 6,
        "pet_friendly"  => true,
        "price_per_day" => "175.0"
      )
    end

    it "omits the listing key entirely when the chat has no rv_listing" do
      other_hirer = create(:user)
      listingless = create(:chat, owner: owner, hirer: other_hirer, rv_listing: nil)
      create(:message, chat: listingless, user: other_hirer, content: "Hello?")

      Ai::ChatReplySuggester.call(chat: listingless, user: owner)

      captured = nil
      expect(
        a_request(:post, "https://api.anthropic.com/v1/messages").with { |req| captured = req.body; true }
      ).to have_been_made
      payload = JSON.parse(JSON.parse(captured)["messages"].first["content"])
      expect(payload).not_to have_key("listing")
    end

    it "declares the owner perspective so the model drafts the owner's reply" do
      Ai::ChatReplySuggester.call(chat: chat, user: owner)
      expect(sent_payload["perspective"]).to eq("owner")
    end

    context "when no chat is given" do
      it "raises Ai::InputError and does not call Claude" do
        expect { Ai::ChatReplySuggester.call(chat: nil, user: owner) }
          .to raise_error(Ai::InputError)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).not_to have_been_made
      end
    end
  end
end
