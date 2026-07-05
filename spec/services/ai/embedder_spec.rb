require 'rails_helper'

RSpec.describe Ai::Embedder do
  let(:embedding) { Array.new(768) { 0.01 } }
  let(:ollama_url) { "http://ollama:11434/api/embeddings" }

  let(:ollama_success_body) { { embedding: embedding }.to_json }

  before do
    stub_request(:post, ollama_url)
      .to_return(status: 200, body: ollama_success_body, headers: { "Content-Type" => "application/json" })
  end

  describe ".call" do
    it "returns the embedding vector from Ollama" do
      result = Ai::Embedder.call("Caravan in Byron Bay, NSW.", feature: "nl_search")
      expect(result).to eq(embedding)
    end

    it "writes a success row to ai_requests with zero cost" do
      user = create(:user)

      expect {
        Ai::Embedder.call("Caravan in Byron Bay, NSW.", feature: "listing_embedding", user: user)
      }.to change(AiRequest, :count).by(1)

      record = AiRequest.last
      expect(record.feature).to eq("listing_embedding")
      expect(record.model).to eq("nomic-embed-text")
      expect(record.success).to be true
      expect(record.estimated_cost_usd).to eq(0)
      expect(record.user).to eq(user)
    end

    context "when Ollama returns an error" do
      before do
        stub_request(:post, ollama_url).to_return(status: 500, body: "internal error")
      end

      it "raises Ai::ApiError" do
        expect {
          Ai::Embedder.call("Caravan in Byron Bay, NSW.", feature: "nl_search")
        }.to raise_error(Ai::ApiError)
      end

      it "writes a failure row to ai_requests" do
        expect {
          Ai::Embedder.call("Caravan in Byron Bay, NSW.", feature: "nl_search")
        }.to raise_error(Ai::ApiError)

        record = AiRequest.last
        expect(record.success).to be false
        expect(record.error_message).to be_present
      end
    end
  end
end
