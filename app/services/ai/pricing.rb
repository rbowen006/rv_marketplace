module Ai
  module Pricing
    # Standard list rates. claude-sonnet-5 is on introductory pricing ($2/$10 per
    # MTok) until 2026-08-31; we deliberately use the standard $3/$15 rather than
    # model dated rates — it over-estimates slightly until then and is exact after,
    # and over-estimating is the safe direction for a cost figure (#67).
    RATES = {
      "claude-sonnet-4-6"  => { input: 0.000003, output: 0.000015 },
      "claude-sonnet-5"    => { input: 0.000003, output: 0.000015 },
      "claude-haiku-4-5"   => { input: 0.0000008, output: 0.000004 }
    }.freeze

    def self.cost_for(model:, input_tokens:, output_tokens:)
      rates = RATES[model]
      return nil unless rates
      (input_tokens * rates[:input]) + (output_tokens * rates[:output])
    end
  end
end
