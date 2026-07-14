class CreateConciergeConversations < ActiveRecord::Migration[8.0]
  # One active conversation per user (ADR-0014). The unique user index enforces
  # "single active conversation per user"; the jsonb transcript holds the exact
  # Anthropic message array (user/assistant/tool blocks) the agent loop resends
  # each turn. A nullable conversation_id on ai_requests lets the N per-call rows
  # of one turn group by conversation while every single-shot feature writes NULL.
  def change
    create_table :concierge_conversations do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: 'idle'
      t.jsonb :transcript, null: false, default: []

      t.timestamps
    end

    add_reference :ai_requests, :conversation, null: true,
                  foreign_key: { to_table: :concierge_conversations }
  end
end
