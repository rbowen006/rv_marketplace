require 'rails_helper'

RSpec.describe Ai::Pricing do
  describe ".cost_for" do
    it "calculates cost for claude-sonnet-4-6 using input and output token rates" do
      cost = Ai::Pricing.cost_for(model: "claude-sonnet-4-6", input_tokens: 1_000_000, output_tokens: 1_000_000)
      expect(cost).to eq(0.000003 * 1_000_000 + 0.000015 * 1_000_000)
    end

    it "returns 0 for zero tokens" do
      cost = Ai::Pricing.cost_for(model: "claude-sonnet-4-6", input_tokens: 0, output_tokens: 0)
      expect(cost).to eq(0)
    end

    it "returns nil for an unknown model" do
      cost = Ai::Pricing.cost_for(model: "unknown-model", input_tokens: 100, output_tokens: 50)
      expect(cost).to be_nil
    end
  end
end
