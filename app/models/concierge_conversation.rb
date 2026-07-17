# A user's single active AI Concierge conversation (ADR-0014). One per user
# (unique index); "Start over" resets it. The jsonb transcript is the source of
# truth — the exact Anthropic message array the agent loop resends each turn.
# The status drives the frontend poller: idle -> processing -> idle | failed.
class ConciergeConversation < ApplicationRecord
  belongs_to :user

  # The AI spend log outlives the conversation (ADR-0014 §Observability, amended):
  # an entry records money already spent, so a reset drops the link rather than the
  # row. Nullify on destroy rather than let the FK raise (#53); the writer nulls the
  # same link when a destroy lands mid-turn (#65).
  has_many :ai_requests, foreign_key: :conversation_id, inverse_of: false, dependent: :nullify

  enum :status, { idle: "idle", processing: "processing", failed: "failed" }, default: :idle
end
