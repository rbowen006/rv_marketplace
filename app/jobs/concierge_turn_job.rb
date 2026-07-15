class ConciergeTurnJob < ApplicationJob
  queue_as :default

  # No Sidekiq retries (ADR-0014, mirroring ADR-0013): each attempt is a paid
  # multi-call Claude turn, so a failure is recorded and the user retries
  # manually rather than letting Sidekiq thrash the API.
  sidekiq_options retry: 0

  # Wall-clock ceiling for one turn (ADR-0014 §Guardrails): kills a stuck loop so
  # the conversation never wedges in `processing` (which would 409 every retry).
  TURN_TIMEOUT = 90 # seconds

  # Runs one queued turn for a conversation the controller has already advanced to
  # `processing` with the user message appended. Continues the agent loop from the
  # persisted transcript, then returns the conversation to idle. Any error marks it
  # failed (message stored) rather than leaving it stuck processing.
  def perform(conversation_id)
    conversation = ConciergeConversation.find_by(id: conversation_id)
    return unless conversation

    transcript = Timeout.timeout(TURN_TIMEOUT) do
      Ai::Concierge.new(conversation: conversation).run
    end

    conversation.update!(status: :idle, transcript: transcript, step_status: nil, error: nil)
  rescue Ai::Error => e
    conversation&.update!(status: :failed, step_status: nil, error: e.message)
  rescue => e
    Rails.logger.error("ConciergeTurnJob #{conversation_id} failed: #{e.class}: #{e.message}")
    conversation&.update!(status: :failed, step_status: nil, error: "Something went wrong. Please try again.")
  end
end
