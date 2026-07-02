module Ai
  module Pricing
    RATES = {
      "claude-sonnet-4-6"  => { input: 0.000003, output: 0.000015 },
      "claude-haiku-4-5"   => { input: 0.0000008, output: 0.000004 }
    }.freeze

    def self.cost_for(model:, input_tokens:, output_tokens:)
      rates = RATES[model]
      return nil unless rates
      (input_tokens * rates[:input]) + (output_tokens * rates[:output])
    end
  end
end
