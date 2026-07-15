class AddErrorAndStepStatusToConciergeConversations < ActiveRecord::Migration[8.0]
  # error holds a failed turn's message (surfaced with a "Try again"); step_status
  # holds the intermediate progress line the poller shows while processing
  # ("Searching listings…") to recover most of the "feels alive" benefit without
  # streaming (ADR-0014 §Transport).
  def change
    add_column :concierge_conversations, :error, :text
    add_column :concierge_conversations, :step_status, :string
  end
end
