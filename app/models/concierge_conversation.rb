# A user's single active AI Concierge conversation (ADR-0014). One per user
# (unique index); "Start over" resets it. The jsonb transcript is the source of
# truth — the exact Anthropic message array the agent loop resends each turn.
# The status drives the frontend poller: idle -> processing -> idle | failed.
class ConciergeConversation < ApplicationRecord
  belongs_to :user

  # Audit rows (ADR-0014) intentionally outlive the conversation: conversation_id
  # is nullable so the AI-spend log survives "Start over". Nullify on destroy
  # rather than let the FK raise (issue #53).
  has_many :ai_requests, foreign_key: :conversation_id, inverse_of: false, dependent: :nullify

  enum :status, { idle: "idle", processing: "processing", failed: "failed" }, default: :idle
end
