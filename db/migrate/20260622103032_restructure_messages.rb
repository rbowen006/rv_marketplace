class RestructureMessages < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM messages"
    add_reference :messages, :chat, null: false, foreign_key: true
    add_column :messages, :read_at, :datetime
    remove_reference :messages, :rv_listing, foreign_key: true
  end

  def down
    remove_reference :messages, :chat, foreign_key: true
    remove_column :messages, :read_at
    add_reference :messages, :rv_listing, null: false, foreign_key: true
  end
end
