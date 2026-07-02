require 'rails_helper'

RSpec.describe Ai::DescriptionGenerator do
  let(:user) { create(:user) }
  let(:valid_params) do
    {
      rv_type: "caravan",
      town: "Byron Bay",
      state: "NSW",
      max_guests: 4,
      pet_friendly: true,
      price_per_day: 180,
      user: user
    }
  end

  let(:anthropic_success_body) do
    {
      id: "msg_123",
      type: "message",
      role: "assistant",
      content: [ { type: "text", text: '{"description":"A beautiful caravan in Byron Bay."}' } ],
      model: "claude-sonnet-4-6",
      stop_reason: "end_turn",
      usage: { input_tokens: 120, output_tokens: 30 }
    }.to_json
  end

  before do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: anthropic_success_body, headers: { "Content-Type" => "application/json" })
  end

  describe ".call" do
    it "sends only a user turn to Claude (no assistant prefill)" do
      Ai::DescriptionGenerator.call(**valid_params)

      expect(
        a_request(:post, "https://api.anthropic.com/v1/messages").with { |req|
          messages = JSON.parse(req.body)["messages"]
          messages.length == 1 && messages.first["role"] == "user"
        }
      ).to have_been_made
    end

    it "returns the generated description" do
      result = Ai::DescriptionGenerator.call(**valid_params)
      expect(result["description"]).to eq("A beautiful caravan in Byron Bay.")
    end

    it "writes a success row to ai_requests" do
      expect { Ai::DescriptionGenerator.call(**valid_params) }
        .to change(AiRequest, :count).by(1)

      record = AiRequest.last
      expect(record.feature).to eq("description_generator")
      expect(record.success).to be true
      expect(record.input_tokens).to eq(120)
      expect(record.output_tokens).to eq(30)
      expect(record.user).to eq(user)
    end

    context "when a required field is missing" do
      it "raises Ai::InputError and does not call Claude" do
        params = valid_params.except(:rv_type)
        expect { Ai::DescriptionGenerator.call(**params) }.to raise_error(Ai::InputError)
        expect(a_request(:post, "https://api.anthropic.com/v1/messages")).not_to have_been_made
      end

      it "writes a failure row to ai_requests" do
        params = valid_params.except(:rv_type)
        expect { Ai::DescriptionGenerator.call(**params) }.to raise_error(Ai::InputError)
        record = AiRequest.last
        expect(record.success).to be false
        expect(record.error_message).to be_present
      end
    end

    context "when Claude returns a 529 (overloaded)" do
      before do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 529, body: '{"error":{"type":"overloaded_error","message":"Overloaded"}}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "raises Ai::ApiError" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }.to raise_error(Ai::ApiError)
      end

      it "writes a failure row to ai_requests" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }.to raise_error(Ai::ApiError)
        expect(AiRequest.last.success).to be false
      end
    end

    context "when Claude returns invalid JSON" do
      before do
        bad_body = {
          id: "msg_456", type: "message", role: "assistant",
          content: [ { type: "text", text: "Sorry, I cannot help with that." } ],
          model: "claude-sonnet-4-6", stop_reason: "end_turn",
          usage: { input_tokens: 50, output_tokens: 10 }
        }.to_json
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: bad_body, headers: { "Content-Type" => "application/json" })
      end

      it "raises Ai::OutputError" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }.to raise_error(Ai::OutputError)
      end

      it "writes a failure row to ai_requests" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }.to raise_error(Ai::OutputError)
        expect(AiRequest.last.success).to be false
      end
    end

    context "when Claude refuses to respond" do
      before do
        refusal_body = {
          id: "msg_789", type: "message", role: "assistant",
          content: [],
          model: "claude-sonnet-4-6", stop_reason: "refusal",
          usage: { input_tokens: 40, output_tokens: 0 }
        }.to_json
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: refusal_body, headers: { "Content-Type" => "application/json" })
      end

      it "raises Ai::ApiError with a message naming the refusal, not a NoMethodError" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }
          .to raise_error(Ai::ApiError, /refusal/)
      end

      it "writes a failure row to ai_requests" do
        expect { Ai::DescriptionGenerator.call(**valid_params) }.to raise_error(Ai::ApiError)
        expect(AiRequest.last.success).to be false
      end
    end
  end
end
