# A user's single active AI Concierge conversation (ADR-0014). One per user
# (unique index); "Start over" resets it. The jsonb transcript is the source of
# truth — the exact Anthropic message array the agent loop resends each turn.
# The status drives the frontend poller: idle -> processing -> idle | failed.
class ConciergeConversation < ApplicationRecord
  belongs_to :user

  enum :status, { idle: 'idle', processing: 'processing', failed: 'failed' }, default: :idle
end
