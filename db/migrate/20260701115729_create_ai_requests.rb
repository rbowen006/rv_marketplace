class CreateAiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_requests do |t|
      t.string  :feature,             null: false
      t.string  :model,               null: false
      t.string  :prompt_version,      null: false
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :latency_ms
      t.decimal :estimated_cost_usd,  precision: 10, scale: 6
      t.boolean :success,             null: false, default: false
      t.string  :error_message
      t.text    :request_payload
      t.text    :response_payload
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
