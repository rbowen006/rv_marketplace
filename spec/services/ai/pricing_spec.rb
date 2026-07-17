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

  # cost_for returns nil for a model it doesn't know, and write_ai_request stores
  # that nil without complaint — so a model missing from RATES logs no cost at all
  # rather than failing loudly (#67). ADR-0014 sanctions per-feature MODEL
  # overrides, so this guards the next one too. It checks presence, not accuracy:
  # rates drift, and estimated_cost_usd is an estimate by design.
  describe "RATES coverage" do
    # Ai::RequestLogging is what routes a call's cost through Ai::Pricing, so
    # including it is exactly what makes a service's model need a rate.
    # Ai::Embedder is excluded by that same test rather than by name: it hardcodes
    # estimated_cost_usd: 0.0 because Ollama runs locally and is free.
    def priced_models
      Rails.application.eager_load!
      services = Ai.constants.map { |name| Ai.const_get(name) }
                   .select { |klass| klass.is_a?(Class) && klass.ancestors.include?(Ai::RequestLogging) }
      overrides = services.filter_map { |klass| klass.const_get(:MODEL) if klass.const_defined?(:MODEL, false) }
      ([ Ai::BaseAiService::DEFAULT_MODEL ] + overrides).uniq
    end

    it "prices every model an AI service can call" do
      unpriced = priced_models.reject { |model| Ai::Pricing::RATES.key?(model) }

      expect(unpriced).to be_empty,
        "These models are called but have no Ai::Pricing::RATES entry, so every " \
        "call logs estimated_cost_usd: nil — #{unpriced.join(', ')}"
    end
  end
end
