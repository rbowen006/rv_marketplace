class CreateTripPlans < ActiveRecord::Migration[8.0]
  # One regenerable trip plan per booking (ADR-0013). The unique booking index
  # makes double-submit idempotent; input_hash lets an unchanged re-run no-op.
  def change
    create_table :trip_plans do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: 'pending'
      t.text :interests
      t.jsonb :itinerary
      t.text :error
      t.string :input_hash

      t.timestamps
    end
  end
end
