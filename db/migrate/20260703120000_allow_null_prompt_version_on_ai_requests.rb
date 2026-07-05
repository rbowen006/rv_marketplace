class AllowNullPromptVersionOnAiRequests < ActiveRecord::Migration[8.0]
  # Embedding calls (ADR-0011) have no prompt file and therefore no
  # prompt_version. The column was Claude-specific; relax the NOT NULL so
  # embedder rows can leave it null.
  def change
    change_column_null :ai_requests, :prompt_version, true
  end
end
